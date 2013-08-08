##########  Configuration   #########

have_winston = false
# # Check whether Winston is installed
# macro usingif(status, sym)
#     if Pkg.installed(string(sym)) != nothing
#         return expr(:toplevel, {expr(:using, {sym}), :($(esc(status)) = true)})
#     end
#     :($(esc(status)) = false)
# end
# 
# @usingif have_winston Winston

# Find a system image viewer
imshow_cmd = ""
@unix_only begin
if !have_winston
    imshow_cmd_list = ["feh", "gwenview", "open"]
    for thiscmd in imshow_cmd_list
        _, p = readsfrom(`which $thiscmd`)
        wait(p)
        if success(p)
            imshow_cmd = thiscmd
            break
        end
    end
end
end
