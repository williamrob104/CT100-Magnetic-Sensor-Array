import os
import numpy as np


def vstack(a, b):
    b = np.append(np.array(b), np.zeros(a.shape[1]-len(b)))
    return np.append(a, b.reshape(1,-1), axis=0)


def rectangular_coil(x_width, y_width, fillet, offset, sides=65535):
    corners = [
        ( x_width/2 - fillet, -y_width/2 + fillet - offset),
        ( x_width/2 - fillet,  y_width/2 - fillet),
        (-x_width/2 + fillet,  y_width/2 - fillet),
        (-x_width/2 + fillet, -y_width/2 + fillet)]

    trace_type = []
    trace_x = np.empty(shape=(0,3))
    trace_y = np.empty(shape=(0,3))

    x_prev, y_prev = x_width/2, -y_width/2
    for i in range(1,sides+1):
        if i % 4 == 0:
            fillet -= offset
            if fillet + np.min(corners[1]) < 0:
                break
        if fillet > 0:
            theta = np.linspace(np.pi/2*(i-1), np.pi/2*i, 3)
            x = corners[i%4][0] + fillet * np.cos(theta)
            y = corners[i%4][1] + fillet * np.sin(theta)
            trace_type.append('line')
            trace_x = vstack(trace_x, [x_prev, x[0]])
            trace_y = vstack(trace_y, [y_prev, y[0]])
            trace_type.append('arc')
            trace_x = vstack(trace_x, x)
            trace_y = vstack(trace_y, y)
            x_prev, y_prev = x[2], y[2]
        else:
            x = corners[i%4][0] + fillet * (1 if   i%4<2 else -1)
            y = corners[i%4][1] + fillet * (1 if 0<i%4<3 else -1)
            trace_type.append('line')
            trace_x = vstack(trace_x, [x_prev, x])
            trace_y = vstack(trace_y, [y_prev, y])
            x_prev, y_prev = x, y

    return trace_type, trace_x, trace_y


def square_board(board_width, board_fillet, hole_spacing=None, hole_diameter=None):
    cut_type = []
    cut_x = np.empty(shape=(0,3))
    cut_y = np.empty(shape=(0,3))

    for i in range(4):
        corner_x = (board_width/2 - board_fillet) * (-1 if 0<i<3 else 1)
        corner_y = (board_width/2 - board_fillet) * (-1 if 1<i   else 1)
        theta = np.linspace(np.pi/2*i, np.pi/2*(i+1), 3)
        x = corner_x + board_fillet * np.cos(theta)
        y = corner_y + board_fillet * np.sin(theta)
        cut_type.append('arc')
        cut_x = vstack(cut_x, x)
        cut_y = vstack(cut_y, y)
    for i in range(4):
        cut_type.append('line')
        cut_x = vstack(cut_x, [cut_x[i,2], cut_x[(i+1)%4, 0]])
        cut_y = vstack(cut_y, [cut_y[i,2], cut_y[(i+1)%4, 0]])

    if hole_spacing is not None:
        for i in range(4):
            hole_x = hole_spacing/2 * (-1 if 0<i<3 else 1)
            hole_y = hole_spacing/2 * (-1 if 1<i   else 1)
            cut_type.append('circle')
            cut_x = vstack(cut_x, [hole_x, hole_x + hole_diameter/2])
            cut_y = vstack(cut_y, [hole_y, hole_y])

    return cut_type, cut_x, cut_y


def draw_trace(f, trace_type, x, y, width, layer):
    edgecut_layer = 'Edge.Cuts'
    if layer != edgecut_layer:
        post = f'(width {width}) (layer "{layer}")'
    else:
        post = f'(stroke (width 0.1) (type default)) (layer "{layer}")'
    for i in range(len(trace_type)):
        if trace_type[i] == 'arc':
            entity = 'arc' if layer != edgecut_layer else 'gr_arc'
            f.write(f'  ({entity} (start {x[i,0]} {y[i,0]}) (mid {x[i,1]} {y[i,1]}) (end {x[i,2]} {y[i,2]}) {post})\n')
        elif trace_type[i]  == 'line':
            entity = 'segment' if layer != edgecut_layer else 'gr_line'
            f.write(f'  ({entity} (start {x[i,0]} {y[i,0]}) (end {x[i,1]} {y[i,1]}) {post})\n')
        elif trace_type[i]  == 'circle':
            entity = 'circle' if layer != edgecut_layer else 'gr_circle'
            f.write(f'  ({entity} (center {x[i,0]} {y[i,0]}) (end {x[i,1]} {y[i,1]}) {post})\n')


# parameters in mm
board_center = (100, 100)
board_width = 100
board_fillet = 10.7
board_margin = 0.5
trace_width = 0.4
trace_offset = 0.6
coil_fillet = 10
hole_spacing = 44
hole_diameter = 2.1
# number of turns for each coil
coil_turns = 33


cut_type,x,y = square_board(board_width, board_fillet, hole_spacing, hole_diameter)
cutout = (cut_type, x+board_center[0], y+board_center[1], 0.1, 'Edge.Cuts')

coil_x_width = (board_width - board_margin*2 - trace_width - trace_offset) / 2
coil_y_width =  board_width - board_margin*2 - trace_width
coil_offset = (coil_x_width + trace_offset) / 2

trace_type,x,y = rectangular_coil(coil_x_width, coil_y_width, coil_fillet, trace_offset, coil_turns*4)
traces = [
    (trace_type, -x+board_center[0]+coil_offset, -y+board_center[1], trace_width, 'F.Cu'),
    (trace_type,  x+board_center[0]-coil_offset, -y+board_center[1], trace_width, 'F.Cu'),
    # (trace_type,  x+board_center[0]+coil_offset, -y+board_center[1], trace_width, 'B.Cu'),
    # (trace_type, -x+board_center[0]-coil_offset, -y+board_center[1], trace_width, 'B.Cu'),
]

vias = [
    # ((127, 100), 0.8, 0.4),
    # (( 73, 100), 0.8, 0.4),
]

current_dir = os.path.dirname(os.path.realpath(__file__))
filename = os.path.join(current_dir, "coil-board.kicad_pcb")

with open(filename, 'r+') as f:
    text = f.read()
    text = text[:text.rfind(')')]
    f.seek(0)
    f.write(text)

    draw_trace(f, *cutout)

    for trace in traces:
        draw_trace(f, *trace)

    for via in vias:
        pos = via[0]
        size = via[1]
        drill = via[2]
        f.write(f'  (via (at {pos[0]} {pos[1]}) (size {size}) (drill {drill}) (layers "F.Cu" "B.Cu"))\n')

    f.write('\n)\n')
    f.truncate()
