# edge-app-schedule-value-notification
Edge app with notification on certain times.

Works like the standard value notification app but include only certain times that the alarm should trigger.

The app uses timezone and DST from Europe/Stockholm. And it is a litte rough. It changes DST at the right date but at midnight instead od 02:00 and 03:00.

The threshold is set in the app interface and should be easy to configure.

IoT Open standard notifications is used. Here is an example notification message. Just to illustrate.

```
Installation: {{.installation.Name}}
Device: {{.payload.device.meta.name}}
Function: {{.payload.func.meta.name}}
Value: {{.payload.value}}
Action: {{.payload.action}} (over or under)
```
.payload.func  and payload.device are the complete function and device objects. 
