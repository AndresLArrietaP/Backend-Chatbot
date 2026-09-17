# -*- coding: utf-8 -*-
import json, os
EQUIPO = [
 ("/ultimo <eq> <comp>", "Último análisis de un componente"),
 ("/condicion <eq>", "Condición de los MT del equipo"),
 ("/diagnostico <eq>", "Diagnóstico (observados) del equipo"),
 ("/diagcompleto <eq>", "Diagnóstico con TODOS los parámetros"),
 ("/tendencia <eq> <comp>", "Tendencia (últimas muestras) de un componente"),
 ("/tendenciadet <eq> <comp>", "Tendencia detalle (metales × fechas)"),
 ("/tendenciametal <eq> <metal>", "Tendencia de un metal en todos los comp."),
 ("/grafica <eq> <comp> <metal>", "Gráfica de un metal"),
 ("/historial <eq> <comp>", "Historial (bitácora) de un componente"),
 ("/historialeq <eq>", "Historial de todo el equipo"),
 ("/historialmetal <eq> <metal> [comp]", "Historial de un metal"),
 ("/acumulados <eq>", "Acumulados del motor diésel del equipo"),
]
FLOTA = [
 ("/barrido <proj> [modelo]", "Barrido: equipos observados de la flota"),
 ("/barridodet <proj> [modelo]", "Barrido detalle por componente"),
 ("/triage <comp> <proj> [modelo]", "Triage: estado de un componente en la flota"),
 ("/incipiente <proj>", "Tendencia incipiente (alerta temprana MT)"),
 ("/conteo <proj> [modelo]", "Conteo de la flota"),
 ("/ranking <proj> <comp> <metal> [top]", "Ranking de un metal"),
 ("/metalflota <proj> <comp> <metal(es)> [modelo]", "Último de un metal en la flota"),
 ("/historialflota <proj>", "Historial de observados de la flota"),
 ("/rankingacum <proj>", "Ranking de acumulados (motor diésel)"),
]
# Adaptive Card borra los <...> (los lee como etiqueta HTML) -> usar guillemets ‹ › para requeridos
EQUIPO=[(c.replace("<","‹").replace(">","›"), q) for c,q in EQUIPO]
FLOTA =[(c.replace("<","‹").replace(">","›"), q) for c,q in FLOTA]
def cell(t, bold=False):
    return {"type":"TableCell","items":[{"type":"TextBlock","text":t,"wrap":True,"size":"Small",**({"weight":"Bolder"} if bold else {})}]}
def table(rows):
    tr=[{"type":"TableRow","cells":[cell("Comando",1),cell("Qué hace",1)],"style":"accent"}]
    for c,q in rows: tr.append({"type":"TableRow","cells":[cell(c),cell(q)]})
    return {"type":"Table","columns":[{"width":2},{"width":3}],"gridStyle":"default","firstRowAsHeaders":True,"rows":tr}
card={
 "type":"AdaptiveCard","$schema":"http://adaptivecards.io/schemas/adaptive-card.json","version":"1.5",
 "body":[
   {"type":"TextBlock","text":"🛠️ Comandos KomfIA","weight":"Bolder","size":"Large","wrap":True},
   {"type":"TextBlock","text":"Escribe **/** + módulo + parámetros.","wrap":True,"isSubtle":True,"spacing":"None"},
   {"type":"TextBlock","text":"**‹campo›** = obligatorio · **[campo]** = opcional (tiene valor por defecto). Componente = tracción/hidráulico/rueda/mando/transmisión/motor · Metal = Fe, Cu, Cr, Pb, Sn, Si, Na, K…","wrap":True,"isSubtle":True,"spacing":"None"},
   {"type":"TextBlock","text":"🔧 Por equipo","weight":"Bolder","spacing":"Medium","color":"Accent"},
   table(EQUIPO),
   {"type":"TextBlock","text":"🚛 Por flota","weight":"Bolder","spacing":"Medium","color":"Accent"},
   table(FLOTA),
   {"type":"TextBlock","text":"Si falta un dato requerido, te lo pido en el chat. El `/` solo actúa pegado a un comando; tu lenguaje natural sigue igual.","wrap":True,"isSubtle":True,"size":"Small","spacing":"Medium"}
 ]
}
json.dumps(card)  # valida
out="docs/copilot/tarjetas"; os.makedirs(out,exist_ok=True)
open(out+"/comandos_card.json","w",encoding="utf-8").write(json.dumps(card,ensure_ascii=False,indent=2))
print("OK card escrita:", out+"/comandos_card.json", "| filas:", len(EQUIPO)+len(FLOTA))
