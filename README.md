# edge-app-schedule-value-notification
Edge app with notification on certain times.

Works like the standard value notification add but include only certain times that the alarm should trigger.


Example notification message.

```
Installation: {{.installation.Name}}
Value: {{.payload.value}}
Function: {{.payload.func.meta.name}}
Action: {{.payload.action}} (over or under)
```
.payload.func is the complete function object. 
