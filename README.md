![title](https://raw.githubusercontent.com/memoriasIT/ESXi-Auto/master/Title.png)
Automatization of the ESXi hypervisor via shell scripts.

### Requirements

Access to the ESXi Shell (can be remote via ssh or whatever you are used to).
Tested with ESXi 5+, it is based mostly on basic linux commands and vim-cmd commands (pre-installed with esxi) so you should be fine if you have them.

### How to install

Just clone the repo and run lol

### Note

All sh files have a help function that will run if the script is called without parameters, it should be enough to help you.
getops does not come installed in esxi so I did not parse the arguments of the scripts, so order matters ($1, $2, etc.).

### Contributions

As always, contributions are accepted, please open a pull request or issue with ideas/code.


### License

GNU GPLv2 


The GNU GPL is the most widely used free software license and has a strong copyleft requirement. When distributing derived works, the source code of the work must be made available under the same license. There are multiple variants of the GNU GPL, each with different requirements.

### Acknowledgements

Thanks Stack Overflow and people in the VMWare forums. 
Also @m-salama in freepik for the psd template for the title.
