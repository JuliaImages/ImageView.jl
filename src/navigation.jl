### GUI controls for play forward/backward, up/down, and frame stepping ###

module Navigation

using Tk

## Type for holding GUI state
# This specifies a particular 2d slice from a possibly-4D image
type NavigationState
    # Dimensions:
    zmax::Int    # = 1 if only 2 spatial dims
    tmax::Int    # = 1 if only a single image
    # Current selection:
    z::Int
    t::Int
    isplaying::Bool # are we in continuous playback?
end

## Type for holding "handles" to GUI controls
type NavigationControls
    stepup                            # buttons...
    stepdown
    playup
    playdown
    stepback
    stepfwd
    playback
    playfwd
    stop
    editz                             # edit boxes
    editt
    textz                             # static text (information)
    textt
end
NavigationControls() = NavigationControls(nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing)

# f is a TkFrame
function init_navigation!(f, ctrls::NavigationControls, state::NavigationState, showframe::Function)
    btnsz, pad = widget_size()
    stop = trues(btnsz)
    mask = copy(stop)
    stop[[1,btnsz[1]],:] = false
    stop[:,[1,btnsz[2]]] = false
    bkg = "gray70"
    icon = Tk.Image(stop, mask, bkg, "black")
    ctrls.stop = Tk.Button(f, icon)
    Tk.tk_bind(ctrls.stop, "command", path -> state.isplaying = false)
    local zindex
    local tindex
    local stopindex
    havez = state.zmax > 1
    havet = state.tmax > 1
    zindex = 1:6
    stopindex = 7
    tindex = 8:13
    if !havez
        stopindex = 1
        tindex = 2:7
    end
    Tk.grid(ctrls.stop,1,stopindex,{:padx => 3*pad, :pady => pad})
    if havez
        callback = (path->stepz(1,ctrls,state,showframe), path->playz(1,ctrls,state,showframe), 
            path->playz(-1,ctrls,state,showframe), path->stepz(-1,ctrls,state,showframe),
            path->setz(ctrls,state,showframe))
        ctrls.stepup, ctrls.playup, ctrls.playdown, ctrls.stepdown, ctrls.textz, ctrls.editz = 
            addbuttons(f, btnsz, bkg, pad, zindex, "z", callback)
        Tk.set_value(ctrls.editz, string(state.z))
    end
    if havet
        callback = (path->stept(-1,ctrls,state,showframe), path->playt(-1,ctrls,state,showframe), 
            path->playt(1,ctrls,state,showframe), path->stept(1,ctrls,state,showframe),
            path->sett(ctrls,state,showframe))
        ctrls.stepback, ctrls.playback, ctrls.playfwd, ctrls.stepfwd, ctrls.textt, ctrls.editt = 
            addbuttons(f, btnsz, bkg, pad, tindex, "t", callback)
        Tk.set_value(ctrls.editt, string(state.t))
    end
end

function widget_size()
    btnsz = (21, 21)
    pad = 5
    return btnsz, pad
end

# Functions for drawing icons
function arrowheads(sz, vert::Bool)
    datasm = icondata(sz, 0.5)
    datalg = icondata(sz, 0.8)
    if vert
        return datasm[:,end:-1:1], datalg[:,end:-1:1], datalg, datasm
    else
        datasm = datasm'
        datalg = datalg'
        return datasm[end:-1:1,:], datalg[end:-1:1,:], datalg, datasm
    end
end

function icondata(iconsize, frac)
    center = iceil(iconsize[1]/2)
    data = Bool[ 2abs(i-center)< iconsize[2]-(j-1)/frac for i = 1:iconsize[1], j = 1:iconsize[2] ]
    data .== true
end

# index contains the grid position of each object
# orientation is "t" or "z"
# callback is an array of 5 entries, the 5th being the edit box
function addbuttons(f, sz, bkg, pad, index, orientation, callback)
    rotflag = orientation == "z"
    ctrl = Array(Any, 6)
    ctrl[1], ctrl[2], ctrl[3], ctrl[4] = arrowheads(sz, rotflag)
    mask = trues(sz)
    const color = ("black", "green", "green", "black")
    ibutton = [1,2,5,6]
    for i = 1:4
        icon = Tk.Image(ctrl[i], mask, bkg, color[i])
        b = Tk.Button(f, icon)
        Tk.grid(b,1,index[ibutton[i]],{:padx => pad, :pady => pad})
        Tk.tk_bind(b, "command", callback[i])
        ctrl[i] = b
    end
    ctrl[5] = Tk.Label(f, orientation*":")
    Tk.grid(ctrl[5],1,index[3], {:padx => pad, :pady => pad})
    ctrl[6] = Tk.Entry(f, "1")
    Tk.tk_configure(ctrl[6], {:width => 5})
    Tk.grid(ctrl[6],1,index[4],{:padx => pad, :pady => pad})
    Tk.tk_bind(ctrl[6], "<Return>", callback[5])
    tuple(ctrl...)
end

function updatez(ctrls, state)
    Tk.set_value(ctrls.editz, string(state.z))
    enabledown = state.z > 1
    set_enabled(ctrls.stepdown, enabledown)
    set_enabled(ctrls.playdown, enabledown)
    enableup = state.z < state.zmax
    set_enabled(ctrls.stepup, enableup)
    set_enabled(ctrls.playup, enableup)
end

function updatet(ctrls, state)
    Tk.set_value(ctrls.editt, string(state.t))
    enableback = state.t > 1
    set_enabled(ctrls.stepback, enableback)
    set_enabled(ctrls.playback, enableback)
    enablefwd = state.t < state.tmax
    set_enabled(ctrls.stepfwd, enablefwd)
    set_enabled(ctrls.playfwd, enablefwd)
end

function incrementt(inc, ctrls, state, showframe)
    state.t += inc
    updatet(ctrls, state)
    showframe(state)
end

function incrementz(inc, ctrls, state, showframe)
    state.z += inc
    updatez(ctrls, state)
    showframe(state)
end

function stepz(inc, ctrls, state, showframe)
    if 1 <= state.z+inc <= state.zmax
        incrementz(inc, ctrls, state, showframe)
    end
end

function playz(inc, ctrls, state, showframe)
    state.isplaying = true
    while 1 <= state.z+inc <= state.zmax && state.isplaying
        Tk.tcl_doevent()    # allow the stop button to take effect
        incrementz(inc, ctrls, state, showframe)
    end
    state.isplaying = false
end

function setz(ctrls,state, showframe)
    zstr = Tk.get_value(ctrls.editz)
    try
        val = int(zstr)
        state.z = val
        updatez(ctrls, state)
        showframe(state)
    catch
        updatez(ctrls, state)
    end
end

function stept(inc, ctrls, state, showframe)
    if 1 <= state.t+inc <= state.tmax
        incrementt(inc, ctrls, state, showframe)
    end
end

function playt(inc, ctrls, state, showframe)
    state.isplaying = true
    while 1 <= state.t+inc <= state.tmax && state.isplaying
        Tk.tcl_doevent()    # allow the stop button to take effect
        incrementt(inc, ctrls, state, showframe)
    end
    state.isplaying = false
end

function sett(ctrls,state, showframe)
    tstr = Tk.get_value(ctrls.editt)
    try
        val = int(tstr)
        state.t = val
        updatet(ctrls, state)
        showframe(state)
    catch
        updatet(ctrls, state)
    end
end

export NavigationState,
    NavigationControls,
    init_navigation!

end
