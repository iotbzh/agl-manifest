There are some manual steps to have Alexa working:

1) set the right microphone for voice agent
You will likely use a USB microphone (e.g. a USB webcam)
Wait for the board to boot (first boot will take more time because all the widgets are being installed). 
Then check the device name with **arecord -l**, and set the short name aac.audio section of this file:

*/usr/local/lib/afm/applications/alexa-voiceagent-service/0.1/var/config/AlexaAutoCoreEngineConfig.json*


```
"speechRecognizer": "hw:HD",
```

(in our case, we have a Creative Webcam, and mic name is **HD**)

2) reboot
3) you can check alexa's status with this command:

```
journalctl -f -u afm-service-alexa-voiceagent-service--0.1--main@0.service
```
and it will complain because the connection token is no longer valid.

4) connection

Alexa must connect to Amazon. **This procedure must be executed each time the board is rebooted, or the agent restarted**

please clone this repo:

```
git@github.com:iotbzh/vshl-htdocs.git
```

and open **index.html** (with Chrome)

Set the target IP:port, the port is the one displayed at the beginning of the output of this command:

```
journalctl  -u afm-service-alexa-voiceagent-service--0.1--main@0.service
...
Mar 24 05:54:02 m3ulcb afbd-alexa-voiceagent-service@0.1[4743]: --    "monitoring": true,
Mar 24 05:54:02 m3ulcb afbd-alexa-voiceagent-service@0.1[4743]: --    "port": 31029,
Mar 24 05:54:02 m3ulcb afbd-alexa-voiceagent-service@0.1[4743]: --    "token": "HELLO",
...
```

in the current example, it is **31029**

Click on login, (the red button must becom green, and named **Alexa VoiceAgent Binder WD Active**

Click on **Subscribe to CBL Events**. You must see things appear in the 3 *Question/Response/Events* text boxes.

In the **Events** text box, you can see the URL for registering your product (Typically, this is <https://amazon.com/us/code>,
followed by the product code (something like **"code\": \"DPJJZB\"**)

Please open that URL, login with you Amazon account, and enter that product code.

Alexa should be connected at this point.

5) talk

To talk to her, you can either click the blue button on the homescreen, or issue this
command in a ssh terminal:

```
afb-client-demo --human 'localhost:31029/api?token=HELLO&uuid=magic' alexa-voiceagent startListening
```

Do not preprend your sentence with "Alexa..."

6) Wakeword

The wakeword is the ability to put Alexa into Listening mode, without step 5), by saying **Alexa...** first.
The integration if this feature is in progress and it is not avaible in this version.

