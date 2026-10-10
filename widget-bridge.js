'use strict';
const config=window.WIDGET_CONFIG || window.ESCAPE_DATA.BaseWidgets.find(w=>w.Id===window.WIDGET_ID).script.config;
const handlers={};let savedState=window.WIDGET_STATE||null;
const send=(type,payload)=>parent.postMessage({escapeWidget:true,widgetId:window.WIDGET_ID,type,...payload},'*');
for(const [k,v] of Object.entries(config)){if(v && v.$type === 'font')document.documentElement.style.setProperty('--font-family-'+k,'"'+v.name+'",sans-serif');}
window.genially={config,connect:async()=>config,on:(event,fn)=>{handlers[event]=fn;},runAction:action=>send('action',{action}),canTrack:()=>false,fireInteractivity:()=>{},onTrackingState:fn=>fn({canAnswer:true}),getState:async()=>savedState,setState:async state=>{savedState=state;send('state',{state});}};
addEventListener('message',e=>{if(e.source!==parent||typeof e.data?.escapeMute!=='boolean')return;document.querySelectorAll('audio,video').forEach(a=>a.muted=e.data.escapeMute);});
