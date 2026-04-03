# Utility functions

# Git Aliases (mirroring .zshrc)
function gc    { git commit -m $args }
function gca   { git commit -a -m $args }
function gp    { git push origin HEAD }
function gpu   { git pull origin }
function gst   { git status }
function glog  { git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit }
function gdiff { git diff $args }
function gco   { git checkout $args }
function gb    { git branch $args }
function gba   { git branch -a $args }
function gadd  { git add $args }
function ga    { git add -p $args }
function gcoall { git checkout -- . }
function gr    { git remote $args }
function gre   { git reset $args }

# Docker
function dco { docker compose $args }
function dps { docker ps $args }
function dpa { docker ps -a $args }
function dl  { docker ps -l -q }
function dx  { docker exec -it $args }

# Directory Navigation
function cd..    { Set-Location .. }
function cd...   { Set-Location ../.. }
function cd....  { Set-Location ../../.. }
function cd..... { Set-Location ../../../.. }
function cd...... { Set-Location ../../../../.. }

function cx {
    if ($args) { Set-Location $args }
    l
}

# Kubernetes (conditional)
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    function k    { kubectl $args }
    function ka   { kubectl apply -f $args }
    function kg   { kubectl get $args }
    function kd   { kubectl describe $args }
    function kdel { kubectl delete $args }
    function kl   { kubectl logs -f $args }
    function ke   { kubectl exec -it $args }
    function kgpo { kubectl get pod $args }
    function kgd  { kubectl get deployments $args }
    function kc   { kubectx $args }
    function kns  { kubens $args }
    function kcns { kubectl config set-context --current --namespace $args }
}

# Eza (conditional)
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function l     { eza -l --icons --git -a $args }
    function lt    { eza --tree --level=2 --long --icons --git $args }
    function ltree { eza --tree --level=2 --icons --git $args }
} else {
    function l { Get-ChildItem $args }
}

# Security Tools (conditional)
function gobust   { gobuster dir --wordlist ~/security/wordlists/diccnoext.txt --wildcard --url $args }
function dirsearch { python dirsearch.py -w db/dicc.txt -b -u $args }
function massdns  { ~/hacking/tools/massdns/bin/massdns -r ~/hacking/tools/massdns/lists/resolvers.txt -t A -o S bf-targets.txt -w livehosts.txt -s 4000 $args }
function server   { python -m http.server 4445 }
function tunnel   { ngrok http 4445 }
function fuzz     { ffuf -w ~/hacking/SecLists/content_discovery_all.txt -mc all -u $args }

# FZF navigation (conditional)
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    function fcd {
        $dir = fd --type d --hidden --follow --exclude .git | fzf
        if ($dir) { Set-Location $dir; l }
    }
    function f {
        fd --type f --hidden --follow --exclude .git | fzf
    }
    function fv {
        $file = fd --type f --hidden --follow --exclude .git | fzf
        if ($file) { nvim $file }
    }
}

# Ranger
function rr { ranger $args }

# Just (conditional)
if (Get-Command just -ErrorAction SilentlyContinue) {
    function j { just $args }
}

Export-ModuleMember -Function * -Alias *
