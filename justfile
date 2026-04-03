# https://just.systems

default:
    @just --list

synclocal:
   git push local master 

stow:
   stow .

# Bootstrap full environment (setup.sh)
install:
	bash setup.sh
