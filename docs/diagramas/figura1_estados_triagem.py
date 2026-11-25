# Figura 1 (vertical, para caber legível na largura da página) – máquina de estados UML da TriageSession.
import math, sys
from PIL import Image, ImageDraw, ImageFont

S = 2
W, H = 1700, 2000
img = Image.new('RGB', (W * S, H * S), 'white')
g = ImageDraw.Draw(img)
F = lambda size, bold=False: ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf' if bold else 'C:/Windows/Fonts/arial.ttf', size * S)
f_state, f_code, f_lab, f_title = F(36, True), F(28), F(28), F(30, True)
INK, GRAY, ACC = (30, 30, 30), (110, 110, 110), (20, 70, 120)
SW, SH = 420, 120
def P(x, y): return (x * S, y * S)

def state(cx, cy, title, code, fill=(232, 241, 250)):
    x0, y0, x1, y1 = cx - SW / 2, cy - SH / 2, cx + SW / 2, cy + SH / 2
    g.rounded_rectangle([*P(x0, y0), *P(x1, y1)], radius=28 * S, fill=fill, outline=ACC, width=3 * S)
    g.text(P(cx, cy - 18), title, font=f_state, fill=INK, anchor='mm')
    g.text(P(cx, cy + 26), code, font=f_code, fill=GRAY, anchor='mm')
    return dict(cx=cx, cy=cy, l=x0, r=x1, t=y0, b=y1)

def arrow(p0, p1):
    (x0, y0), (x1, y1) = p0, p1
    g.line([*P(x0, y0), *P(x1, y1)], fill=INK, width=3 * S)
    a = math.atan2(y1 - y0, x1 - x0); L = 26
    pts = [(x1, y1), (x1 - L * math.cos(a - .38), y1 - L * math.sin(a - .38)), (x1 - L * math.cos(a + .38), y1 - L * math.sin(a + .38))]
    g.polygon([P(*p) for p in pts], fill=INK)

def label(x, y, lines, anchor='mm'):
    text = '\n'.join(lines)
    bb = g.multiline_textbbox(P(x, y), text, font=f_lab, anchor=anchor, align='center', spacing=5 * S)
    pad = 7 * S
    g.rectangle([bb[0] - pad, bb[1] - pad, bb[2] + pad, bb[3] + pad], fill='white')
    g.multiline_text(P(x, y), text, font=f_lab, fill=INK, anchor=anchor, align='center', spacing=5 * S)

def initial(cx, cy, r=18): g.ellipse([*P(cx - r, cy - r), *P(cx + r, cy + r)], fill=INK)
def final(cx, cy, r=22):
    g.ellipse([*P(cx - r, cy - r), *P(cx + r, cy + r)], outline=INK, width=3 * S, fill='white')
    g.ellipse([*P(cx - r + 8, cy - r + 8), *P(cx + r - 8, cy + r - 8)], fill=INK)

BX0, BY0, BX1, BY1 = 60, 140, 1640, 1560
g.rounded_rectangle([*P(BX0, BY0), *P(BX1, BY1)], radius=34 * S, outline=GRAY, width=3 * S, fill=(250, 250, 250))
g.text(P(BX0 + 26, BY0 + 22), 'Triagem ativa', font=f_title, fill=GRAY, anchor='la')

tri = state(850, 280, 'Em triagem', 'in_triage')
chk = state(390, 660, 'Aguardando check-in', 'awaiting_checkin')
val = state(1310, 660, 'Aguardando validação', 'awaiting_validation')
que = state(850, 1060, 'Na fila', 'in_queue')
att = state(850, 1420, 'Em atendimento', 'in_attendance')
exp = state(390, 1760, 'Expirada', 'expired', fill=(245, 245, 245))
com = state(850, 1760, 'Concluída', 'completed', fill=(236, 247, 238))
can = state(1310, 1760, 'Cancelada', 'cancelled', fill=(245, 245, 245))

initial(850, 50); arrow((850, 68), (850, tri['t']))
label(880, 100, ['solicitante inicia'], anchor='lm')
arrow((tri['l'] + 60, tri['b']), (chk['cx'] + 60, chk['t']))
label(330, 430, ['IA encerra', '[check-in exigido', 'e não emergência]'])
arrow((tri['r'] - 60, tri['b']), (val['cx'] - 60, val['t']))
label(1370, 430, ['IA encerra', '[validação exigida e', '(sem check-in', 'ou emergência)]'])
arrow((850, tri['b']), (850, que['t']))
arrow((chk['r'], 660), (val['l'], 660))
label(850, 610, ['check-in [validação exigida]'])
label(850, 860, ['IA encerra', '[sem validação e', '(sem check-in', 'ou emergência)]'])
arrow((chk['cx'] + 80, chk['b']), (que['l'] + 40, que['t']))
label(500, 880, ['check-in', '[sem validação]'], anchor='rm')
arrow((val['cx'] - 80, val['b']), (que['r'] - 40, que['t']))
label(1200, 880, ['colaborador', 'confirma ou ajusta'], anchor='lm')
arrow((850, que['b']), (850, att['t']))
label(880, 1240, ['colaborador chama'], anchor='lm')
arrow((850, att['b']), (850, com['t']))
label(880, 1630, ['especialista finaliza'], anchor='lm')
arrow((chk['cx'] - 120, chk['b']), (exp['cx'] - 120, exp['t']))
label(290, 1240, ['[prazo de', 'check-in', 'esgotado]'], anchor='lm')
arrow((can['cx'], BY1), (can['cx'], can['t']))
label(1340, 1630, ['solicitante reinicia', 'ou cancela [a partir de', 'qualquer estado ativo]'], anchor='lm')
for st in (exp, com, can):
    arrow((st['cx'], st['b']), (st['cx'], 1915)); final(st['cx'], 1940)

img.resize((W, H), Image.LANCZOS).save(sys.argv[1], dpi=(250, 250))
print('ok')
