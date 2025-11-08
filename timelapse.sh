#!/data/data/com.termux/files/usr/bin/bash

exec &> >(tee ~/logs/timelapse.log)

echo
echo "Timelapse parameters"
CAMERA=0
DATE=$(date +"%Y%m%d_%H%M%S")
DIR=$(date +"%Y%m")
NAME=${DATE}.jpeg
CREDENTIALS="ftp200037909:K7TNBPgnvwch94vg"
SERVER="ngcobalt411.manitu.net"

echo "take image ${NAME}"
termux-camera-photo -c $CAMERA $NAME


if [ -f "${NAME}" ];then

  echo "mkdir ${DIR}"
  curl -Q "MKD ${DIR}" ftp://${SERVER} --user "${CREDENTIALS}" -v -4 -C - --retry 30 --retry-delay 10 --max-time 1000 --limit-rate 64k || true

  echo "upload ${NAME}"
  curl -T ${NAME} ftp://${SERVER}/${DIR}/${NAME} --user "${CREDENTIALS}" -v -4 -C - --retry 30 --retry-delay 10 --max-time 1000 --limit-rate 64k

  ##############
  curl -Q "-DELE ip.txt" -Q "-DELE battery.txt" ftp://${SERVER}/ --user "${CREDENTIALS}" -v -4 -C - --retry 30 --retry-delay 10 --max-time 1000 --limit-rate 64k

  echo "upload current ip"
  echo $(curl -s https://ipinfo.io/ip) > ip.txt
  curl -T ip.txt ftp://${SERVER}/ --user "${CREDENTIALS}" -v -4 -C - --retry 30 --retry-delay 10 --max-time 1000 --limit-rate 64k

  echo "upload battery"
  termux-battery-status > battery.txt
  curl -T battery.txt ftp://${SERVER}/ --user "${CREDENTIALS}" -v -4 -C - --retry 30 --retry-delay 10 --max-time 1000 --limit-rate 64k

else
  echo "${NAME} not available"
fi

echo "removing ${NAME}"
rm -v ${NAME}
