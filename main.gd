extends Control


#region Server
var server_source : Variant
var server_source_manifest : PackedStringArray
var server : TCPServer
var connected_peers : Array[StreamPeerTCP] = []


func _server_browse_button_press() -> void:
	$SourceSelect.show()


func recursive_scanner(folder : DirAccess):
	if not is_instance_valid(folder): return
	for file in folder.get_files():
		server_source_manifest.append(folder.get_current_dir()+"/"+file)
	for dir in folder.get_directories():
		recursive_scanner.call(DirAccess.open(folder.get_current_dir()+"/"+dir))


func confirm_source_selection():
	print(server_source)
	if server_source is DirAccess:
		server_source_manifest = []
		recursive_scanner(server_source)
		$"TabContainer/Send Files/FileSelect/WhatIsSelected".text = "Selected a folder of %d files" % [len(server_source_manifest)]
	elif server_source is FileAccess:
		server_source_manifest = [server_source.get_path_absolute()] # Only sharing one file
		$"TabContainer/Send Files/FileSelect/WhatIsSelected".text = "Selected a single .%s file" % [server_source.get_path().split(".")[-1]]


func _server_source_typed(new_text: String) -> void:
	var diraccess = DirAccess.open(new_text)
	var fileaccess = FileAccess.open(new_text,FileAccess.READ)
	if is_instance_valid(diraccess):
		print("Selected a valid directory")
		server_source = diraccess
		confirm_source_selection()
	if is_instance_valid(fileaccess):
		print("Selected a valid file")
		server_source = fileaccess
		confirm_source_selection()


func _server_source_dir_select(dir: String) -> void:
	$"TabContainer/Send Files/FileSelect/LineEdit".text = dir
	var diraccess = DirAccess.open(dir)
	server_source = diraccess
	confirm_source_selection()


func _server_source_file_select(path: String) -> void:
	$"TabContainer/Send Files/FileSelect/LineEdit".text = path
	var fileaccess = FileAccess.open(path,FileAccess.READ)
	server_source = fileaccess
	confirm_source_selection()


func _host_server() -> void:
	server = TCPServer.new()
	server.listen($"TabContainer/Send Files/ServerControl/SpinBox".value)
	$"TabContainer/Send Files/ServerControl/ServerStatusLabel".text = "Server Active"


func _process(_delta : float) -> void:
	if not is_instance_valid(server): return # Check if we are a server before continuing.
	
	# Prepare UI for an update
	var peerlist : RichTextLabel = $"TabContainer/Send Files/PeerList/RichTextLabel"
	peerlist.clear()
	
	# Accept incoming connections
	if server.is_connection_available():
		connected_peers.append(server.take_connection())
	
	# Talk to peers...
	for peer in connected_peers:
		peer.poll()
		
		if peer.get_status() == StreamPeerSocket.STATUS_CONNECTED:
			# Refresh UI
			peerlist.add_text(peer.get_connected_host()+":"+str(peer.get_connected_port())+"\n")
			
			var peer_request_length = peer.get_available_bytes()
			if peer_request_length > 0:
				var peer_request = peer.get_utf8_string(peer_request_length)
				var head_body_separator_position = peer_request.find("\r\n\r\n")
				var request_body : Dictionary = JSON.parse_string(peer_request.right(-head_body_separator_position-4).remove_chars("'"))
				print("Requested action: ",request_body.action)
				match request_body.action:
					"manifest": # Respond with the size of manifest
						var stringified_body : String = JSON.stringify({"manifest": len(server_source_manifest)})
						var final_response : String = \
							"HTTP/1.1 200 OK\r\n" + \
							"Content-Type: application/json\r\n" + \
							("Content-Length: %d\r\n" % len(stringified_body)) + \
							"\r\n" + \
							stringified_body
						# Respond
						peer.put_data(final_response.to_utf8_buffer())
					"download": # Respond with a file.
						# Identify requested file
						var requested_file_id : int = request_body.fileid
						print("Requested file: #%d (%s)" % [requested_file_id, server_source_manifest[requested_file_id]])
						# Open requested file
						var requested_file : FileAccess = FileAccess.open(server_source_manifest[requested_file_id],FileAccess.READ)
						# Calculate relative file path
						var relative_file_path : String = ""
						if server_source is DirAccess:
							relative_file_path = requested_file.get_path_absolute().right(-server_source.get_current_dir().length()).get_base_dir()+"/"
						elif server_source is FileAccess:
							relative_file_path = "/"
						# Respond with initial header
						var response_header : String = \
							"HTTP/1.1 200 OK\r\n" + \
							"Content-Type: application/octet-stream\r\n" + \
							("Content-Length: %d\r\n" % requested_file.get_length()) + \
							("FSD-Filename: %s\r\n" % requested_file.get_path_absolute().split("/")[-1]) + \
							("FSD-Relative-Path: %s\r\n" % relative_file_path) + \
							"Connection: Close\r\n" + \
							"\r\n"
						peer.put_data(response_header.to_utf8_buffer())
						# Stream file data
						while not requested_file.eof_reached():
							peer.put_data(requested_file.get_buffer(8192))
				peer.disconnect_from_host()
#endregion


#region Client
@onready var client : HTTPRequest = $HTTPRequest
var file_download_destination : DirAccess
var is_downloading_something : bool = false


func _download_destination_select() -> void:
	$DestinationSelect.show()


func set_download_destination(destination_path : String) -> void:
	file_download_destination = DirAccess.open(destination_path)
	if not is_instance_valid(file_download_destination):
		$"TabContainer/Receive Files/Progress/Label".text = "Status: Download destination invalid"
		$"TabContainer/Receive Files/ServerSpecifier/Button".disabled = true
	else:
		$"TabContainer/Receive Files/Progress/Label".text = "Status: Ready"
		$"TabContainer/Receive Files/ServerSpecifier/Button".disabled = false


func _client_destination_chosen(dir: String) -> void:
	$"TabContainer/Receive Files/DownloadDestination/LineEdit".text = dir
	set_download_destination(dir)


func _download_destination_typed(new_text: String) -> void:
	set_download_destination(new_text)


func _on_download_pressed() -> void:
	var target_url : String = "http://"+$"TabContainer/Receive Files/ServerSpecifier/LineEdit".text
	client.request(target_url,[],HTTPClient.METHOD_POST,JSON.stringify({
		"action": "manifest"
	}))


func _on_server_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if "Content-Type: application/json" in headers:
		var response : Dictionary = JSON.parse_string(body.get_string_from_utf8())
		$"TabContainer/Receive Files/Progress/Label".text = "Status: Connected."
		$"TabContainer/Receive Files/Progress/ProgressBar/TextProgress".show()
		$"TabContainer/Receive Files/Progress/ProgressBar/TextProgress".text = "0/%d" % response.manifest
		$"TabContainer/Receive Files/Progress/ProgressBar".max_value = response.manifest
		$"TabContainer/Receive Files/Progress/ProgressBar".value = 0
		
		for i in range(response.manifest):
			client.request("http://"+$"TabContainer/Receive Files/ServerSpecifier/LineEdit".text,[],HTTPClient.METHOD_GET,JSON.stringify({
				"action": "download",
				"fileid": i
			}))
			is_downloading_something = true
			while is_downloading_something:
				await get_tree().process_frame
	elif "Content-Type: application/octet-stream" in headers:
		$"TabContainer/Receive Files/Progress/ProgressBar".value += 1
		$"TabContainer/Receive Files/Progress/ProgressBar/TextProgress".text = str(int($"TabContainer/Receive Files/Progress/ProgressBar".value))+"/"+str(int($"TabContainer/Receive Files/Progress/ProgressBar".max_value))
		DirAccess.make_dir_recursive_absolute(file_download_destination.get_current_dir()+headers[3].split(": ")[1])
		var downloaded_file = FileAccess.open(file_download_destination.get_current_dir()+headers[3].split(": ")[1]+headers[2].split(": ")[1],FileAccess.WRITE)
		$"TabContainer/Receive Files/Progress/ProgressLog".add_text("Downloaded file %s\n" % [headers[2].split(": ")[1]])
		downloaded_file.store_buffer(body)
		downloaded_file.close()
		is_downloading_something = false


#endregion
