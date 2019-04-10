There are some manual steps to have Alexa working:

1) set the right microphone for voice agent
You will likely use a USB microphone (e.g. a USB webcam)
Wait for the board to boot (first boot will take more time because all the widgets are being installed). 
Then check the device name with "arecord -l", and set the short name aac.audio section of this file:

/usr/local/lib/afm/applications/alexa-voiceagent-service/0.1/var/config/AlexaAutoCoreEngineConfig.json

     "speechRecognizer": "hw:HD",

(in our case,mic name is 'HD')

2) reboot
3) you can check alexa's status with this command:

journalctl -f -u afm-service-alexa-voiceagent-service--0.1--main@0.service
and it will complain because the connection token is no longer valid.
To fix that,
please clone this repo:
git@github.com:iotbzh/vshl-htdocs.git

and open index.html (with Chrome)

Set the target IP:port, the port is the one displayed at the beginning of

journalctl  -u afm-service-alexa-voiceagent-service--0.1--main@0.service

```
Mar 24 05:54:02 m3ulcb afbd-alexa-voiceagent-service@0.1[4743]: --    "monitoring": true,
Mar 24 05:54:02 m3ulcb afbd-alexa-voiceagent-service@0.1[4743]: --    "port": 31029,
Mar 24 05:54:02 m3ulcb afbd-alexa-voiceagent-service@0.1[4743]: --    "token": "HELLO",
```

in the current example, it is 31029
Click on login, and connect to one Amazon Account you have.

Alexa should be connected at this point.

To talk to her, you can either start your question with "Alexa ..." or click the blue
button on the homescreen.

