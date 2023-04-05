import os
import numpy as np

def rectangular_coil(x_width, y_width, fillet, offset, sides=65535):
    corners = [
        ( x_width/2 - fillet, -y_width/2 + fillet - offset),
        ( x_width/2 - fillet,  y_width/2 - fillet),
        (-x_width/2 + fillet,  y_width/2 - fillet),
        (-x_width/2 + fillet, -y_width/2 + fillet)]

    x = np.array( x_width/2)
    y = np.array(-y_width/2)
    for i in range(1,sides+1):
        if i % 4 == 0:
            fillet -= offset
            if fillet + np.min(corners[1]) < 0:
                break
        if fillet >= 0:
            theta = np.linspace(np.pi/2*(i-1), np.pi/2*i)
            x = np.append(x, np.cos(theta) * fillet + corners[i%4][0])
            y = np.append(y, np.sin(theta) * fillet + corners[i%4][1])
        else:
            x = np.append(x, corners[i%4][0] + fillet * (1 if   i%4<2 else -1))
            y = np.append(y, corners[i%4][1] + fillet * (1 if 0<i%4<3 else -1))

    return x, y


# parameters in mm
board_center = (100, 100)
board_width = 100
board_fillet = 8
board_margin = 2
trace_width = 0.4
trace_offset = 0.6
coil_fillet = 10
# number of turns for each coil
coil_turns = 33


cutout = []
for i in range(4):
    corner_x = board_center[0] + (board_width/2 - board_fillet) * (-1 if 0<i<3 else 1)
    corner_y = board_center[1] + (board_width/2 - board_fillet) * (-1 if 1<i   else 1)
    edge = ('arc', (corner_x+board_fillet*np.cos(np.pi/2* i    ),corner_y+board_fillet*np.sin(np.pi/2* i    )),
                   (corner_x+board_fillet*np.cos(np.pi/2*(i+.5)),corner_y+board_fillet*np.sin(np.pi/2*(i+.5))),
                   (corner_x+board_fillet*np.cos(np.pi/2*(i+ 1)),corner_y+board_fillet*np.sin(np.pi/2*(i+ 1))) )
    cutout.append(edge)
for i in range(4):
    edge = ('line', cutout[i%4][3], cutout[(i+1)%4][1])
    cutout.append(edge)

coil_x_width = (board_width - board_margin*2 - trace_width - trace_offset) / 2
coil_y_width =  board_width - board_margin*2 - trace_width
coil_offset = (coil_x_width + trace_offset) / 2

x,y = rectangular_coil(coil_x_width, coil_y_width, coil_fillet, trace_offset, coil_turns*4)
traces = [
    (-x+board_center[0]+coil_offset, -y+board_center[1], trace_width, 'F.Cu'),
    ( x+board_center[0]-coil_offset, -y+board_center[1], trace_width, 'F.Cu'),
    ( x+board_center[0]+coil_offset, -y+board_center[1], trace_width, 'B.Cu'),
    (-x+board_center[0]-coil_offset, -y+board_center[1], trace_width, 'B.Cu'),
]

current_dir = os.path.dirname(os.path.realpath(__file__))
filename = os.path.join(current_dir, "coil-board.kicad_pcb")

with open(filename, 'r+') as f:
    text = f.read()
    text = text[:text.rfind(')')]
    f.seek(0)
    f.write(text)

    for edge in cutout:
        type = edge[0]
        if type == 'arc':
            f.write(f'  (gr_arc (start {edge[1][0]} {edge[1][1]}) (mid {edge[2][0]} {edge[2][1]}) (end {edge[3][0]} {edge[3][1]}) (stroke (width 0.1) (type default)) (layer "Edge.Cuts"))\n')
        elif type == 'line':
            f.write(f'  (gr_line (start {edge[1][0]} {edge[1][1]}) (end {edge[2][0]} {edge[2][1]}) (stroke (width 0.1) (type default)) (layer "Edge.Cuts"))\n')

    for trace in traces:
        x = trace[0]
        y = trace[1]
        width = trace[2]
        layer = trace[3]
        for i in range(len(x)-1):
            f.write(f'  (segment (start {x[i]} {y[i]}) (end {x[i+1]} {y[i+1]}) (width {width}) (layer "{layer}"))\n')

    f.write('\n)\n')
    f.truncate()
