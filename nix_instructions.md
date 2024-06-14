# Getting started with BayModTS on Nix

We assume that root permissions are available, if they aren't there is also the
option to install Nix into the home directory rather than into `/nix` but this
is not covered by these install instructions. If that is the call feel free to
reach out and i can extend the getting started guide.

## Install Nix

```bash
# Run to startup the installer
sh <(curl -L https://nixos.org/nix/install) --daemon
# this will be a guided installation and you have to input a couple of times
# `y` to proceed.
# After the installation is done, open a new shell after that Nix should be
# available.
# This can be tested with
nix-shell -p hello
# nix-shell will then download the hello binary into the Nix store and update
# the $PATH env variable.
# Once this is done you should be inside a new bash and can execute the hello
# command.
hello
# If the response is "Hello, world!" Nix was installed successfully and Nix can
# be used. You can now leave the nix-shell with `<c-d>` or exit.
# We still need to configure Nix so experimental features are enabled.
mkdir -pv ~/.config/nix
echo "experimental-features = nix-command flakes"  >> ~/.config/nix/nix.conf
# Once this is done we can also test to see if everything works
nix run nixpkgs#hello
# this will also download the hello package and will immediately run it. The
# response is the same
```

At this point Nix should be correctly installed. If you later want to uninstall
Nix again this will be explained later.

Reference Material: https://nix.dev/manual/nix/2.22/installation/

## Getting started with BayModTS using nix

```bash
# Clone BayModTS with the nix branch
git clone -b feat/nix_take3 https://github.com/helsinki-systems/BayModTS.git
# Alternative, if a BayModTS checkout is already present it should be enough
# to do the following
cd BayModTS
git remote add helsinki https://github.com/helsinki-systems/BayModTS.git
git fetch --all
git checkout feat/nix_take3
# After BayModTS feat/nix_take3 branch was successfully checked out you can do
# the following inside that repo.
nix develop
# This will then download and build all required python dependencies and will
# put you in a new shell, once completed.
# In that shell, you can do `jupyter notebook` to start working on the
# notebooks or you can just test if the python packages are correctly installed
# using `python -c "import amici"`. This command should not error and then
# amici is correctly build and in your env, can be used.
```

## Uninstall Nix

```bash
# We first need to stop all services before we can uninstall Nix
sudo systemctl stop nix-daemon.service
sudo systemctl disable nix-daemon.socket nix-daemon.service
sudo systemctl daemon-reload
# now we can remove all files created by Nix
sudo rm -rf /etc/nix /etc/profile.d/nix.sh /etc/tmpfiles.d/nix-daemon.conf /nix ~root/.nix-channels ~root/.nix-defexpr ~root/.nix-profile
rm -rf ~/.config/nix
# Last we need to remove the created nixbd user and groups. This can be done
# like this
for i in $(seq 1 32); do
  sudo userdel nixbld$i
done
sudo groupdel nixbld
```

Reference Material: https://nix.dev/manual/nix/2.22/installation/uninstall
