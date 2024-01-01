Instructions to add authorization with username and password for OpenVPN server and OpenVPN Client

file-name: ovpn-userpass-script  
version 31-12-23  
author: egc  
function: standlone script to incorporate username/password functionality in OpenVPN Server  

## INSTALLATION ##  
### SERVER side ###  
Place this script file in `/etc/openvpn/`  
Make executable: `chmod +x /etc/openvpn/ovpn-userpass-script`  

In the OpenVPN Server config add:  
 `verify-client-cert none` # or `optional` or `require` if you want username password AND cert/key  
 `auth-user-pass-verify /etc/openvpn/ovpn-userpass-script via-env`  
 `script-security 3`  
 `username-as-common-name`  

Create a file with username and password e.g. 'userpass' which is used to validate username and password  
For each client a username and password on the same line separated by a space, *no* spaces in username or password allowed!  
username and password can only consist of alphanumeric, underbar ('_'), dash ('-'), dot ('.'), or at ('@') characters.  
Example of `/etc/openvpn/userpass`:  
 `Hans Worst@2`  
 `John Doe24`  

## CLIENT side ##  
In the OpenVPN Client config add:  
For OpenVPN 2.6 inline in config file:  
 `<auth-user-pass>`  
 `username`  
 `password`   
 `</auth-user-pass>`  

For OpenVPN 2.5 add in Client config: path and filename to text file (e.g.: /etc/openvpn/cl-userpass) with username and password both on separate line:  
 `auth-user-pass /etc/openvpn/cl-userpass`  
Example of /etc/openvpn/cl-userpass:  
 `Hans`  
 `Worst@2`  

## PATCHES ##  
Unfortunately while making this I discovered a bug in OpenVPN.   
`script-security` is always set to `2` when using the installation with the config file, because `script-security` is not parsed from the config file  
With `script-security 2` the password is not used/visible in the environment, script-security has to be set to 3.  
There is a patch available (openvpn-add-script-security-1.patch) for compiling your own build but if you do not want that or cannot compile you have to add the following line on line number 193 of `/etc/openvpn/openvpn.init`:  
`[ -n "$script_security" ] || get_openvpn_option "$config" script_security script-security`  
```
 	if [ ! -z "$config" ]; then
 		append UCI_STARTED "$config" "$LIST_SEP"
-> 		[ -n "$script_security" ] || get_openvpn_option "$config" script_security script-security <-
 		[ -n "$up" ] || get_openvpn_option "$config" up up
 		[ -n "$down" ] || get_openvpn_option "$config" down down
 		openvpn_add_instance "$s" "${config%/*}" "$config" "$script_security" "$up" "$down"
````
