const __bodyfunction__ = Dict{Method,Any}()

# Find keyword "body functions" (the function that contains the body
# as written by the developer, called after all missing keyword-arguments
# have been assigned values), in a manner that doesn't depend on
# gensymmed names.
# `mnokw` is the method that gets called when you invoke it without
# supplying any keywords.
function __lookup_kwbody__(mnokw::Method)
    function getsym(arg)
        isa(arg, Symbol) && return arg
        @assert isa(arg, GlobalRef)
        return arg.name
    end

    f = get(__bodyfunction__, mnokw, nothing)
    if f === nothing
        fmod = mnokw.module
        # The lowered code for `mnokw` should look like
        #   %1 = mkw(kwvalues..., #self#, args...)
        #        return %1
        # where `mkw` is the name of the "active" keyword body-function.
        ast = Base.uncompressed_ast(mnokw)
        if isa(ast, Core.CodeInfo) && length(ast.code) >= 2
            callexpr = ast.code[end-1]
            if isa(callexpr, Expr) && callexpr.head == :call
                fsym = callexpr.args[1]
                if isa(fsym, Symbol)
                    f = getfield(fmod, fsym)
                elseif isa(fsym, GlobalRef)
                    if fsym.mod === Core && fsym.name === :_apply
                        f = getfield(mnokw.module, getsym(callexpr.args[2]))
                    elseif fsym.mod === Core && fsym.name === :_apply_iterate
                        f = getfield(mnokw.module, getsym(callexpr.args[3]))
                    else
                        f = getfield(fsym.mod, fsym.name)
                    end
                else
                    f = missing
                end
            else
                f = missing
            end
        else
            f = missing
        end
        __bodyfunction__[mnokw] = f
    end
    return f
end

function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#18#19")) && precompile(Tuple{getfield(ImageView, Symbol("#18#19")),MouseButton{UserUnit}})
    isdefined(ImageView, Symbol("#20#21")) && precompile(Tuple{getfield(ImageView, Symbol("#20#21")),ZoomRegion{RoundingIntegers.RInt},Int})
    isdefined(ImageView, Symbol("#20#21")) && precompile(Tuple{getfield(ImageView, Symbol("#20#21")),ZoomRegion{RoundingIntegers.RInt}})
    isdefined(ImageView, Symbol("#84#87")) && precompile(Tuple{getfield(ImageView, Symbol("#84#87")),Float32,Float32})
    isdefined(ImageView, Symbol("#84#87")) && precompile(Tuple{getfield(ImageView, Symbol("#84#87")),Float64,Float64})
    isdefined(ImageView, Symbol("#92#95")) && precompile(Tuple{getfield(ImageView, Symbol("#92#95")),AnnotationBox})
    isdefined(ImageView, Symbol("#92#95")) && precompile(Tuple{getfield(ImageView, Symbol("#92#95")),AnnotationPoints{Array{Tuple{Int,Int},1}}})
    let fbody = try __lookup_kwbody__(which(contrast_gui_layout, (Signal{Float32},Signal{Float32},StepRangeLen{Float32,Float64,Float64},))) catch missing end
        if !ismissing(fbody)
            @assert precompile(fbody, (String,typeof(contrast_gui_layout),Signal{Float32},Signal{Float32},StepRangeLen{Float32,Float64,Float64},))
            @assert precompile(fbody, (String,typeof(contrast_gui_layout),Signal{Float64},Signal{Float64},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},))
        end
    end
    let fbody = try __lookup_kwbody__(which(imshow, (AbstractArray,Signal{CLim{Float16}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}},Signal{Dict{UInt,Any}},))) catch missing end
        if !ismissing(fbody)
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{Float16}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{Float32}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}},Signal{Dict{UInt,Any}},))
        end
    end
    let fbody = try __lookup_kwbody__(which(imshow, (AbstractArray,Signal{CLim{Float64}},))) catch missing end
        if !ismissing(fbody)
            @assert precompile(fbody, (Any,Any,Any,Any,typeof(imshow),AbstractArray,Any,))
        end
    end
    let fbody = try __lookup_kwbody__(which(imshow, (AbstractArray,Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{2,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))) catch missing end
        if !ismissing(fbody)
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{2,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{3,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{:z,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{true,1,Tuple{Axis{:R,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{N0f16}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{N0f8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{N0f8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{:S,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{RGB{Float64}}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{RGB{Float64}}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,2,Tuple{Axis{:z,Base.OneTo{Int}},Axis{:time,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{RoundingIntegers.RInt}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),AbstractArray,Signal{CLim{RoundingIntegers.RUInt8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}},Signal{Dict{UInt,Any}},))
        end
    end
    let fbody = try __lookup_kwbody__(which(imshow, (Any,Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,2,Tuple{Axis{1,Base.OneTo{Int}},Axis{4,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))) catch missing end
        if !ismissing(fbody)
            @assert precompile(fbody, (String,Symbol,typeof(imshow),Any,Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,2,Tuple{Axis{1,Base.OneTo{Int}},Axis{4,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))
            @assert precompile(fbody, (String,Symbol,typeof(imshow),Any,Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,2,Tuple{Axis{3,Base.OneTo{Int}},Axis{4,Base.OneTo{Int}}}},Signal{Dict{UInt,Any}},))
        end
    end
    @assert precompile(Tuple{Core.kwftype(typeof(AnnotationLine)),NamedTuple{(:linewidth, :color),Tuple{Int,RGB{N0f8}}},typeof(AnnotationLine),Int,Int,Int,Int})
    @assert precompile(Tuple{Core.kwftype(typeof(AnnotationPoint)),NamedTuple{(:shape, :size, :color),Tuple{Char,Int,RGB{N0f8}}},typeof(AnnotationPoint),Int,Int})
    @assert precompile(Tuple{Core.kwftype(typeof(AnnotationPoint)),NamedTuple{(:shape, :size, :color, :linecolor, :scale),Tuple{Char,Int,RGB{N0f8},RGB{N0f8},Bool}},typeof(AnnotationPoint),Int,Int})
    @assert precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:color, :fontsize),Tuple{RGB{N0f8},Int}},Type{AnnotationText},Int,Int,String})
    @assert precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:linewidth, :color),Tuple{Int,RGB{N0f8}}},Type{AnnotationBox},Int,Int,Int,Int})
    @assert precompile(Tuple{Core.kwftype(typeof(contrast_gui)),NamedTuple{(:wname,),Tuple{String}},typeof(contrast_gui),Signal{Bool},Signal{StatsBase.Histogram{Int,1,Tuple{StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}}}},Signal{CLim{Float64}}})
    @assert precompile(Tuple{Core.kwftype(typeof(contrast_gui_layout)),NamedTuple{(:wname,),Tuple{String}},typeof(contrast_gui_layout),Signal{Float32},Signal{Float32},StepRangeLen{Float32,Float64,Float64}})
    @assert precompile(Tuple{Core.kwftype(typeof(contrast_gui_layout)),NamedTuple{(:wname,),Tuple{String}},typeof(contrast_gui_layout),Signal{Float64},Signal{Float64},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:axes, :name),Tuple{Tuple{Symbol,Symbol},String}},typeof(imshow),AxisArray{Gray{N0f8},3,Array{Gray{N0f8},3},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}},Axis{:S,StepRange{Int,Int}}}},Signal{CLim{Float64}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),AxisArray{Float64,3,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{Axis{:x,Base.OneTo{Int}},Axis{:y,Base.OneTo{Int}},Axis{:z,Base.OneTo{Int}}}},Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{2,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),AxisArray{Float64,3,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{Axis{:x,Base.OneTo{Int}},Axis{:y,Base.OneTo{Int}},Axis{:z,Base.OneTo{Int}}}},Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{3,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),AxisArray{Float64,3,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{Axis{:x,Base.OneTo{Int}},Axis{:y,Base.OneTo{Int}},Axis{:z,Base.OneTo{Int}}}},Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{:z,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),AxisArray{Gray{N0f8},2,MappedArrays.ReadonlyMappedArray{Gray{N0f8},2,Array{Gray{N0f8},2},typeof(identity)},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}}}},Signal{CLim{N0f8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),AxisArray{Gray{N0f8},3,Array{Gray{N0f8},3},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}},Axis{:S,StepRange{Int,Int}}}},Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{true,1,Tuple{Axis{:R,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),AxisArray{Gray{N0f8},3,MappedArrays.ReadonlyMappedArray{Gray{N0f8},3,Array{Gray{N0f8},3},typeof(identity)},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}},Axis{:S,StepRange{Int,Int}}}},Signal{CLim{N0f8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{3,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),AxisArray{Gray{N0f8},3,MappedArrays.ReadonlyMappedArray{Gray{N0f8},3,Array{Gray{N0f8},3},typeof(identity)},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}},Axis{:S,StepRange{Int,Int}}}},Signal{CLim{N0f8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,1,Tuple{Axis{:S,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),AxisArray{RGB24,4,MappedArrays.ReadonlyMappedArray{RGB24,4,Base.ReinterpretArray{RGB24,4,UInt32,Array{UInt32,4}},typeof(identity)},Tuple{Axis{:x,UnitRange{Int}},Axis{:y,UnitRange{Int}},Axis{:z,StepRange{Int,Int}},Axis{:time,UnitRange{Int}}}},Signal{CLim{RGB{Float64}}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,2,Tuple{Axis{:z,Base.OneTo{Int}},Axis{:time,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{Float16,2,Array{Float16,2},typeof(identity)},Signal{CLim{Float16}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{Float32,2,Array{Float32,2},typeof(identity)},Signal{CLim{Float32}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{Float64,2,Array{Float64,2},typeof(identity)},Signal{CLim{Float64}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{Gray{N0f8},2,Array{Gray{N0f8},2},typeof(identity)},Signal{CLim{N0f8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Signal{CLim{RoundingIntegers.RInt}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{N0f16,2,Base.ReinterpretArray{N0f16,2,UInt16,Array{UInt16,2}},typeof(identity)},Signal{CLim{N0f16}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{N0f8,2,Base.ReinterpretArray{N0f8,2,UInt8,Array{UInt8,2}},typeof(identity)},Signal{CLim{N0f8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{N0f8,2,Base.ReshapedArray{N0f8,2,Base.ReinterpretArray{N0f8,1,UInt8,Array{UInt8,1}},Tuple{}},typeof(identity)},Signal{CLim{N0f8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{RGB{Float32},2,Array{RGB{Float32},2},typeof(identity)},Signal{CLim{RGB{Float64}}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{RGB{Float64},2,Base.ReshapedArray{RGB{Float64},2,Base.ReinterpretArray{RGB{Float64},3,Float64,Array{Float64,3}},Tuple{}},typeof(identity)},Signal{CLim{RGB{Float64}}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{RGB{N0f8},2,Array{RGB{N0f8},2},typeof(identity)},Signal{CLim{RGB{Float64}}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),MappedArrays.ReadonlyMappedArray{UInt8,2,Array{UInt8,2},typeof(identity)},Signal{CLim{RoundingIntegers.RUInt8}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{Base.OneTo{Int},StepRange{Int,Int}},false},Signal{CLim{RoundingIntegers.RInt}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{StepRange{Int,Int},Base.OneTo{Int}},false},Signal{CLim{RoundingIntegers.RInt}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshow)),NamedTuple{(:name, :aspect),Tuple{String,Symbol}},typeof(imshow),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{StepRange{Int,Int},StepRange{Int,Int}},false},Signal{CLim{RoundingIntegers.RInt}},Signal{ZoomRegion{RoundingIntegers.RInt}},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{Core.kwftype(typeof(imshowlabeled)),NamedTuple{(:name,),Tuple{String}},typeof(imshowlabeled),Array{Float64,2},Array{Int,2}})
    @assert precompile(Tuple{Core.kwftype(typeof(scalebar)),NamedTuple{(:x, :y),Tuple{Float64,Float64}},typeof(scalebar),Dict{String,Any},Int})
    @assert precompile(Tuple{Type{Dict},Tuple{Pair{String,Dict{String,Any}},Pair{String,Signal{CLim{Float16}}},Pair{String,Dict{String,Any}},Pair{String,Signal{Dict{UInt,Any}}}}})
    @assert precompile(Tuple{Type{Dict},Tuple{Pair{String,Dict{String,Any}},Pair{String,Signal{CLim{Float32}}},Pair{String,Dict{String,Any}},Pair{String,Signal{Dict{UInt,Any}}}}})
    @assert precompile(Tuple{Type{Dict},Tuple{Pair{String,Dict{String,Any}},Pair{String,Signal{CLim{Float64}}},Pair{String,Dict{String,Any}},Pair{String,Signal{Dict{UInt,Any}}}}})
    @assert precompile(Tuple{Type{Dict},Tuple{Pair{String,Dict{String,Any}},Pair{String,Signal{CLim{N0f16}}},Pair{String,Dict{String,Any}},Pair{String,Signal{Dict{UInt,Any}}}}})
    @assert precompile(Tuple{Type{Dict},Tuple{Pair{String,Dict{String,Any}},Pair{String,Signal{CLim{N0f8}}},Pair{String,Dict{String,Any}},Pair{String,Signal{Dict{UInt,Any}}}}})
    @assert precompile(Tuple{Type{Dict},Tuple{Pair{String,Dict{String,Any}},Pair{String,Signal{CLim{RGB{Float64}}}},Pair{String,Dict{String,Any}},Pair{String,Signal{Dict{UInt,Any}}}}})
    @assert precompile(Tuple{Type{Dict},Tuple{Pair{String,Dict{String,Any}},Pair{String,Signal{CLim{RoundingIntegers.RInt}}},Pair{String,Dict{String,Any}},Pair{String,Signal{Dict{UInt,Any}}}}})
    @assert precompile(Tuple{Type{Dict},Tuple{Pair{String,Dict{String,Any}},Pair{String,Signal{CLim{RoundingIntegers.RUInt8}}},Pair{String,Dict{String,Any}},Pair{String,Signal{Dict{UInt,Any}}}}})
    @assert precompile(Tuple{typeof(Base.grow_to!),Dict{String,Dict{String,Any}},Tuple{Pair{String,Dict{String,Any}},Pair{String,Signal{CLim{N0f8}}},Pair{String,Dict{String,Any}},Pair{String,Signal{Dict{UInt,Any}}}},Int})
    @assert precompile(Tuple{typeof(_mappedarray),Function,Array{UInt8,2}})
    if Base.VERSION >= v"1.6.0-DEV.1083"   # julia #37559
        @assert precompile(Tuple{typeof(_mappedarray),Function,AxisArray{RGB24,4,Base.ReinterpretArray{RGB24,4,UInt32,Array{UInt32,4},true},Tuple{Axis{:x,UnitRange{Int}},Axis{:y,UnitRange{Int}},Axis{:z,StepRange{Int,Int}},Axis{:time,UnitRange{Int}}}}})
        @assert precompile(Tuple{typeof(_mappedarray),Function,Base.ReinterpretArray{N0f8,2,UInt8,Array{UInt8,2},true}})
    else
        @assert precompile(Tuple{typeof(_mappedarray),Function,AxisArray{RGB24,4,Base.ReinterpretArray{RGB24,4,UInt32,Array{UInt32,4}},Tuple{Axis{:x,UnitRange{Int}},Axis{:y,UnitRange{Int}},Axis{:z,StepRange{Int,Int}},Axis{:time,UnitRange{Int}}}}})
        @assert precompile(Tuple{typeof(_mappedarray),Function,Base.ReinterpretArray{N0f8,2,UInt8,Array{UInt8,2}}})
    end
    @assert precompile(Tuple{typeof(closeall)})
    @assert precompile(Tuple{typeof(contrast_gui),Signal{Bool},Array{Any,1},Signal{CLim{RGB{Float64}}}})
    @assert precompile(Tuple{typeof(contrast_gui),Signal{Bool},Array{Signal{StatsBase.Histogram{Int,1,Tuple{StepRangeLen{Float32,Float64,Float64}}}},1},Signal{CLim{N0f16}}})
    @assert precompile(Tuple{typeof(default_axes),AxisArray{Gray{N0f8},2,Array{Gray{N0f8},2},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}}}}})
    @assert precompile(Tuple{typeof(default_axes),AxisArray{RGB24,4,Base.ReinterpretArray{RGB24,4,UInt32,Array{UInt32,4}},Tuple{Axis{:x,UnitRange{Int}},Axis{:y,UnitRange{Int}},Axis{:z,StepRange{Int,Int}},Axis{:time,UnitRange{Int}}}}})
    @assert precompile(Tuple{typeof(default_clim),AxisArray{Float64,2,SubArray{Float64,2,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{UnitRange{Int},Int,UnitRange{Int}},false},Tuple{Axis{:x,UnitRange{Int}},Axis{:z,UnitRange{Int}}}}})
    @assert precompile(Tuple{typeof(default_clim),AxisArray{Float64,2,SubArray{Float64,2,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int},Int},false},Tuple{Axis{:x,UnitRange{Int}},Axis{:y,UnitRange{Int}}}}})
    @assert precompile(Tuple{typeof(default_clim),AxisArray{Gray{N0f8},2,SubArray{Gray{N0f8},2,MappedArrays.ReadonlyMappedArray{Gray{N0f8},2,Array{Gray{N0f8},2},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}}}}})
    @assert precompile(Tuple{typeof(default_clim),AxisArray{Gray{N0f8},2,SubArray{Gray{N0f8},2,MappedArrays.ReadonlyMappedArray{Gray{N0f8},3,Array{Gray{N0f8},3},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int},Int},false},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}}}}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{Float16,2,MappedArrays.ReadonlyMappedArray{Float16,2,Array{Float16,2},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{Float32,2,MappedArrays.ReadonlyMappedArray{Float32,2,Array{Float32,2},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{Float64,2,MappedArrays.ReadonlyMappedArray{Float64,2,Array{Float64,2},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{Gray{N0f8},2,MappedArrays.ReadonlyMappedArray{Gray{N0f8},2,Array{Gray{N0f8},2},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{StepRange{Int,Int},StepRange{Int,Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{StepRange{Int,Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{UnitRange{Int},StepRange{Int,Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{N0f16,2,MappedArrays.ReadonlyMappedArray{N0f16,2,Base.ReinterpretArray{N0f16,2,UInt16,Array{UInt16,2}},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{N0f8,2,MappedArrays.ReadonlyMappedArray{N0f8,2,Base.ReinterpretArray{N0f8,2,UInt8,Array{UInt8,2}},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{N0f8,2,MappedArrays.ReadonlyMappedArray{N0f8,2,Base.ReshapedArray{N0f8,2,Base.ReinterpretArray{N0f8,1,UInt8,Array{UInt8,1}},Tuple{}},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(default_clim),SubArray{UInt8,2,MappedArrays.ReadonlyMappedArray{UInt8,2,Array{UInt8,2},typeof(identity)},Tuple{UnitRange{Int},UnitRange{Int}},false}})
    @assert precompile(Tuple{typeof(prep_contrast),GtkReactive.Canvas{UserUnit},Signal{AxisArray{Gray{N0f8},2,SubArray{Gray{N0f8},2,Array{Gray{N0f8},3},Tuple{UnitRange{Int},UnitRange{Int},Int},false},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}}}}},Nothing})
    @assert precompile(Tuple{typeof(prep_contrast),GtkReactive.Canvas{UserUnit},Signal{SubArray{Gray{N0f8},2,Array{Gray{N0f8},2},Tuple{UnitRange{Int},UnitRange{Int}},false}},Signal{CLim{N0f8}}})
    @assert precompile(Tuple{typeof(prep_contrast),GtkReactive.Canvas{UserUnit},Signal{SubArray{RGB{N0f8},2,Array{RGB{N0f8},2},Tuple{UnitRange{Int},UnitRange{Int}},false}},Signal{CLim{RGB{Float64}}}})
    @assert precompile(Tuple{typeof(prep_contrast),GtkReactive.Canvas{UserUnit},Signal{SubArray{RGB{N0f8},2,Array{RGB{N0f8},3},Tuple{UnitRange{Int},UnitRange{Int},Int},false}},Nothing})
    @assert precompile(Tuple{typeof(sliceinds),AxisArray{RGB24,4,MappedArrays.ReadonlyMappedArray{RGB24,4,Base.ReinterpretArray{RGB24,4,UInt32,Array{UInt32,4}},typeof(identity)},Tuple{Axis{:x,UnitRange{Int}},Axis{:y,UnitRange{Int}},Axis{:z,StepRange{Int,Int}},Axis{:time,UnitRange{Int}}}},Tuple{Int,Int},Axis{:z,Int},Vararg{Any,N} where N})
    @assert precompile(Tuple{typeof(annotate!),Dict{String,Any},AnnotationBox})
    @assert precompile(Tuple{typeof(annotate!),Dict{String,Any},AnnotationLines{Float64,Tuple{Tuple{Float64,Float64},Tuple{Float64,Float64}}}})
    @assert precompile(Tuple{typeof(annotate!),Dict{String,Any},AnnotationPoints{Array{Tuple{Int,Int},1}}})
    @assert precompile(Tuple{typeof(annotate!),Dict{String,Any},AnnotationPoints{Tuple{Float64,Float64}}})
    @assert precompile(Tuple{typeof(annotate!),Dict{String,Any},AnnotationText})
    @assert precompile(Tuple{typeof(imlink),AxisArray{Gray{N0f8},3,Array{Gray{N0f8},3},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}},Axis{:S,StepRange{Int,Int}}}},Vararg{Any,N} where N})
    @assert precompile(Tuple{typeof(imshow!),GtkReactive.Canvas{UserUnit},AxisArray{Gray{N0f8},2,Array{Gray{N0f8},2},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}}}}})
    @assert precompile(Tuple{typeof(imshow!),GtkReactive.Canvas{UserUnit},Signal{AxisArray{Gray{N0f8},2,Array{Gray{N0f8},2},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}}}}},Signal{ZoomRegion{RoundingIntegers.RInt}},Signal{Dict{UInt,Any}}})
    @assert precompile(Tuple{typeof(imshow),GtkReactive.Canvas{UserUnit},AbstractArray{T,2} where T})
    @assert precompile(Tuple{typeof(push!),Signal{CLim{Float64}},CLim{Float64}})
    @assert precompile(Tuple{typeof(push!),Signal{CLim{N0f16}},CLim{Float32}})
    @assert precompile(Tuple{typeof(roi),AxisArray{Float64,3,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{Axis{:x,Base.OneTo{Int}},Axis{:y,Base.OneTo{Int}},Axis{:z,Base.OneTo{Int}}}},Tuple{Int,Int}})
    @assert precompile(Tuple{typeof(roi),AxisArray{Float64,3,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{Axis{:x,Base.OneTo{Int}},Axis{:y,Base.OneTo{Int}},Axis{:z,Base.OneTo{Int}}}},Tuple{Symbol,Symbol}})
    @assert precompile(Tuple{typeof(roi),AxisArray{Gray{N0f8},2,MappedArrays.ReadonlyMappedArray{Gray{N0f8},2,Array{Gray{N0f8},2},typeof(identity)},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}}}},Tuple{Symbol,Symbol}})
    @assert precompile(Tuple{typeof(roi),AxisArray{Gray{N0f8},3,MappedArrays.ReadonlyMappedArray{Gray{N0f8},3,Array{Gray{N0f8},3},typeof(identity)},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}},Axis{:S,StepRange{Int,Int}}}},Tuple{Symbol,Symbol}})
    @assert precompile(Tuple{typeof(roi),AxisArray{RGB24,4,MappedArrays.ReadonlyMappedArray{RGB24,4,Base.ReinterpretArray{RGB24,4,UInt32,Array{UInt32,4}},typeof(identity)},Tuple{Axis{:x,UnitRange{Int}},Axis{:y,UnitRange{Int}},Axis{:z,StepRange{Int,Int}},Axis{:time,UnitRange{Int}}}},Tuple{Symbol,Symbol}})
    @assert precompile(Tuple{typeof(slice2d),AxisArray{Float64,3,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{Axis{:x,Base.OneTo{Int}},Axis{:y,Base.OneTo{Int}},Axis{:z,Base.OneTo{Int}}}},ZoomRegion{RoundingIntegers.RInt},SliceData{false,1,Tuple{Axis{2,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{typeof(slice2d),AxisArray{Float64,3,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{Axis{:x,Base.OneTo{Int}},Axis{:y,Base.OneTo{Int}},Axis{:z,Base.OneTo{Int}}}},ZoomRegion{RoundingIntegers.RInt},SliceData{false,1,Tuple{Axis{3,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{typeof(slice2d),AxisArray{Float64,3,MappedArrays.ReadonlyMappedArray{Float64,3,Array{Float64,3},typeof(identity)},Tuple{Axis{:x,Base.OneTo{Int}},Axis{:y,Base.OneTo{Int}},Axis{:z,Base.OneTo{Int}}}},ZoomRegion{RoundingIntegers.RInt},SliceData{false,1,Tuple{Axis{:z,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{typeof(slice2d),AxisArray{Gray{N0f8},2,MappedArrays.ReadonlyMappedArray{Gray{N0f8},2,Array{Gray{N0f8},2},typeof(identity)},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}}}},ZoomRegion{RoundingIntegers.RInt},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{typeof(slice2d),AxisArray{Gray{N0f8},3,MappedArrays.ReadonlyMappedArray{Gray{N0f8},3,Array{Gray{N0f8},3},typeof(identity)},Tuple{Axis{:P,StepRange{Int,Int}},Axis{:R,StepRange{Int,Int}},Axis{:S,StepRange{Int,Int}}}},ZoomRegion{RoundingIntegers.RInt},SliceData{false,1,Tuple{Axis{:S,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{typeof(slice2d),AxisArray{RGB24,4,MappedArrays.ReadonlyMappedArray{RGB24,4,Base.ReinterpretArray{RGB24,4,UInt32,Array{UInt32,4}},typeof(identity)},Tuple{Axis{:x,UnitRange{Int}},Axis{:y,UnitRange{Int}},Axis{:z,StepRange{Int,Int}},Axis{:time,UnitRange{Int}}}},ZoomRegion{RoundingIntegers.RInt},SliceData{false,2,Tuple{Axis{:z,Base.OneTo{Int}},Axis{:time,Base.OneTo{Int}}}}})
    @assert precompile(Tuple{typeof(slice2d),MappedArrays.ReadonlyMappedArray{Float16,2,Array{Float16,2},typeof(identity)},ZoomRegion{RoundingIntegers.RInt},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{typeof(slice2d),MappedArrays.ReadonlyMappedArray{Gray{N0f8},2,Array{Gray{N0f8},2},typeof(identity)},ZoomRegion{RoundingIntegers.RInt},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{typeof(slice2d),MappedArrays.ReadonlyMappedArray{N0f8,2,Base.ReinterpretArray{N0f8,2,UInt8,Array{UInt8,2}},typeof(identity)},ZoomRegion{RoundingIntegers.RInt},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{typeof(slice2d),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{Base.OneTo{Int},StepRange{Int,Int}},false},ZoomRegion{RoundingIntegers.RInt},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{typeof(slice2d),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{StepRange{Int,Int},Base.OneTo{Int}},false},ZoomRegion{RoundingIntegers.RInt},SliceData{false,0,Tuple{}}})
    @assert precompile(Tuple{typeof(slice2d),SubArray{Int,2,MappedArrays.ReadonlyMappedArray{Int,2,Array{Int,2},typeof(identity)},Tuple{StepRange{Int,Int},StepRange{Int,Int}},false},ZoomRegion{RoundingIntegers.RInt},SliceData{false,0,Tuple{}}})
end
