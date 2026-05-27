# HasteWarp
A program for free transfer of an unlimited amount of files at maximum speed. Made with Godot Engine.
# Origin
One time, my friend wanted to send me a 5 gigabyte video. But Telegram capped uploads at 2 gigabytes with only option to increase the cap being subscribing to Telegram Premium. Discord caps uploads at 8 megabytes and its paid subscription only increases it to 100 megabytes.
We considered having it uploaded to a Google Drive, but Google once banned his account for uploading a video that was deemed to be against Terms of Service.
<br>Notably, he has ability to open ports on his network, so I decided to write this program.
# Mechanism
This program transfers files using HTTP file streaming features. Both client and server are created entirely in [Godot Engine](https://www.godotengine.org), the HTTP server was created out of Godot's built-in TCPServer class (apparently, it doesn't have anything like a "HTTPServer" class) and the HTTP client is a simple interface to a built-in HTTPRequest node.
<br>This program is capped entirely by the user's computer speed, their network speed and whatever restrictions imposed by the ISP, but doesn't collect subscription or interface with any sort of cloud.
# Usecases
- Use this program if you're performing transfers on a local wi-fi network or have ethernet connection between computers.<br>
- You may also use this program if you can open ports on your network.<br>
- You may also use this program if you have a virtual local network established, e.g. via Hamachi, Radmin VPN, corporate VPN or academic VPN (e.g. University of New Brunswick has a proxy server for remote connections)
# Instructions
Written in the interface.
# Screenshots
<img width="1154" height="680" alt="image" src="https://github.com/user-attachments/assets/91f1142d-d502-4b5f-8101-c77e0e02ed5b" />
<img width="1154" height="680" alt="image" src="https://github.com/user-attachments/assets/21436e62-92e7-4503-bfb1-10c0acc14e3b" />
