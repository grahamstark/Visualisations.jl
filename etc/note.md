Hi,

I have this [little app written in Dash](https://stb.virtual-worlds.scot/bcd/). It runs on Dash's default port 8050. Normally when I write little specialist servers like this I stick Apache with `mod-redirect` in front of them so only port 80 needs to be open and so the link just looks like a normal one. So:

    RewriteRule /bcd/(.*) http://localhost:8050/$1 [P,QSA]
     
maps `/bcd/` to `localhost:8050`

but this doesn't work correctly with Dash 

.... 
