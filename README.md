## What's that all about
The script in `timelapse.sh` is a Bash script for capturing a photo using Termux, 
uploading it to an FTP server, and handling status files. 
It uses environment variables `FTP_SERVER`, `FTP_USER`, and `FTP_PASS` for FTP credentials. 
The script ensures it only runs once at a time by storing its PID in a file and checking 
for existing instances. It is modularized with functions for each task (e.g., photo capture, upload, 
logging, cleanup). There is an option to skip uploading the image file by modifying the main function logic. 
The script also manages log files and status files (IP, battery, WiFi), 
and can execute remote commands or update crontab if special files are found on the FTP server.

## Requirements
- Termux environment on Android
- Installed packages: `curl`, `ftp`, `termux-camera-photo`
- FTP server access
- A `.timelapse.env` file with FTP credentials
- Optional: cron job setup for periodic execution
- On some smartphones it is necessary to have the app tasker run on boot to start termux-api app thus the workflow will succeed
### How to use
1. Set up Termux on your Android device and install necessary packages (e.g., `
2. curl`, `ftp`, `termux-camera-photo`).
3. Create a `.timelapse.env` file with your FTP server details:
   ```
   FTP_SERVER=your_ftp_server
   FTP_USER=your_ftp_username
   FTP_PASS=your_ftp_password
   ```
4. Make the script executable: `chmod +x timelapse.sh`.
5. Run the script: `./timelapse.sh`.
6. (Optional) Set up a cron job to run the script at desired intervals.
   example: `*/5 * * * * cd /data/data/com.termux/files/home/timelapse; ./timelapse.sh`
7. if you have a prepaid card with whats app you can use the cmd.sh load mechanism to send a whatsapp message to pay
   example cmd.sh file content:
   ```
   termux-sms-send -n 25000 Test
   ```