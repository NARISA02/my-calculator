(()=>{"use strict";
const formulas=[
{name:"เที่ยงคืน",map:["238","146","053","948","856","713","681","589","436","405"]},
{name:"ตี 1",map:["246","357","468","579","068","179","028","139","024","135"]},
{name:"ตี 2",map:["245","368","047","689","123","579","014","358","679","436"]},
{name:"ตี 3",map:["157","568","679","780","189","029","013","124","235","346"]},
{name:"ตี 4",map:["167","279","389","478","158","269","347","458","569","678"]}
];
function mount(){
 if(document.getElementById("time-specific-formulas-panel"))return;
 const style=document.createElement("style");style.textContent="#time-specific-formulas-panel{margin:14px 0;padding:14px;border:1px solid #d6c18a;border-radius:14px;background:#fffaf0;color:#44351a;font:inherit}#time-specific-formulas-panel h3{margin:0 0 8px;font-size:1.1em}#time-specific-formulas-panel .tsf-controls{display:flex;gap:8px;flex-wrap:wrap;align-items:end}#time-specific-formulas-panel label{display:block;font-size:.9em;font-weight:700;margin:4px 0}#time-specific-formulas-panel select{min-width:110px;padding:8px;border:1px solid #cdbb8d;border-radius:8px;background:#fff;color:#222;font:inherit}#time-specific-formulas-panel .tsf-output{margin-top:10px;padding:10px;border-radius:10px;background:#fff}#time-specific-formulas-panel .tsf-omit{font-size:1.35em;font-weight:900;color:#8a4b08}#time-specific-formulas-panel .tsf-play{margin-top:4px;font-weight:700;color:#176447}#time-specific-formulas-panel .tsf-note{font-size:.82em;color:#76684d;margin-top:6px}";
 document.head.appendChild(style);
 const panel=document.createElement("section");panel.id="time-specific-formulas-panel";
 panel.innerHTML='<h3>สูตรใหม่ตามช่วงเวลา (เพิ่ม 5 สูตร)</h3><div class="tsf-controls"><div><label for="tsf-time">เลือกสูตร</label><select id="tsf-time"></select></div><div><label for="tsf-digit">เลือกเลขตั้งต้น 0–9</label><select id="tsf-digit"></select></div></div><div class="tsf-output"><div>เลขเว้น 3 ตัว</div><div class="tsf-omit" id="tsf-omit">—</div><div class="tsf-play" id="tsf-play"></div></div><div class="tsf-note">เลือกสูตรและเลขตั้งต้น ระบบจะแสดงเลขเว้น 3 ตัวและเลขที่เหลือ 7 ตัว โดยไม่เปลี่ยนสูตรเดิมของห้องนี้</div>';
 const target=document.querySelector("main")||document.body;target.appendChild(panel);
 const time=panel.querySelector("#tsf-time"),digit=panel.querySelector("#tsf-digit");
 formulas.forEach((f,i)=>time.add(new Option(f.name,f.name)));
 for(let i=0;i<10;i++)digit.add(new Option(String(i),String(i)));
 function calc(){const f=formulas.find(x=>x.name===time.value)||formulas[0],n=Number(digit.value),omit=f.map[n].split(""),play=Array.from({length:10},(_,i)=>String(i)).filter(x=>!omit.includes(x));panel.querySelector("#tsf-omit").textContent=omit.join(" • ");panel.querySelector("#tsf-play").textContent="เลขที่เหลือ 7 ตัว: "+play.join(" • ");}
 time.addEventListener("change",calc);digit.addEventListener("change",calc);calc();
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",mount,{once:true});else mount();
})();