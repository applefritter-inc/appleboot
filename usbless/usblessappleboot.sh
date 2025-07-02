cdn = ""
echo "Downloading payload..."
curl -LO "$cdn"/bootloader.zip
unzip bootloader.zip
chmod +x *
./main.sh
