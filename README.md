# Development releases of LuaTeX in TeX Live

> *Disclaimer:*  I don't take any responsibility for your broken TeX Live installation.

The only architecture available at the moment is `x86_64-linux`.

## Install

```
curl -fsSL http://hmenke.github.io/texlive-luatex-dev/luatex-dev.asc | tlmgr key add -
tlmgr repository add http://hmenke.github.io/texlive-luatex-dev luatex-dev
tlmgr pinning add luatex-dev "*"
tlmgr update --self --all
tlmgr install luatex --reinstall
```

## Remove

```
tlmgr pinning remove luatex-dev "*"
tlmgr install luatex --reinstall
```
