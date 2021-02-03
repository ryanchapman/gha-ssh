# gha-ssh
GitHub Action which allows you to ssh into a container during CI runs.

I've tried to limit the number of dependencies and only write in bash
to make it easier to do a security review.  

# Dependencies

## Base container

Debian (`debian:buster-slim`)

## Debian packages

We install a few Debian packages in the `Dockerfile`:

- curl
- locales-all
- openssh-client
- openssh-server
- vim
- wget
- xz-utils

To see the installation command, refer to https://github.com/ryanchapman/gha-ssh/blob/main/Dockerfile#L3

## Tmate

tmate is the primary service that allows this all to work.  When the gha-ssh container starts,
it will run tmate, which starts an ssh connection to the tmate.io servers, essentially forming 
a tunnel.  We start tmate with `-a ~/authorized_keys`, which allows only certain users to 
log into the container.  The `~/authorized_keys` file is the same format as openssh's 
authorized keys file.  It holds public ssh keys (one per line).  When a user connects, a 
challenge is sent to the connecting user, which the user signs with their private ssh key.
The signature is sent back to tmate running in the gha-ssh container, which uses the public 
key to verify that the challenge was signed using the private key.

We use version 2.4.0 of tmate, which
is distributed as a `tar.xz` file at 
https://github.com/tmate-io/tmate/releases/download/2.4.0/tmate-2.4.0-static-linux-amd64.tar.xz

To see the installation command, refer to https://github.com/ryanchapman/gha-ssh/blob/main/Dockerfile#L7

To see how tmate is set up and started, refer to the main function in `entrypoint.bash`:
https://github.com/ryanchapman/gha-ssh/blob/main/entrypoint.bash#L130

# Usage

At the point where you want to ssh in, add a step that runs the `ryanchapman/gha-ssh` action:

```
name: continuous deployment
on:
 push

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: ssh
      uses: ryanchapman/gha-ssh@v1
      # after the container starts tmate in the background, it will
      # sleep for 24 hours, so it's important that you set a timeout here
      # so you don't run up your GitHub Actions bill
      timeout-minutes: 10
      with:
        # authorized_github_users: required
        # List of GitHub users who are allowed to ssh into container.
        # On gha-ssh container start, it downloads the ssh public key(s) for each
        # user from GitHub and places it in ~/authorized_keys
        # tmate is started with `-a ~/authorized_keys` to only allow access
        # to users with possession of the corresponding private ssh keys.
        authorized_github_users: 'johndoe,janedoe'
        # debug: optional
        # defaults to `false` if not set here
        # if debug is set, then tmate is started with `-vvv -F`
        debug: true
```

For additional information on the action and inputs, see action.yml at
https://github.com/ryanchapman/gha-ssh/blob/main/action.yml

# Example run

```
Feb 03 17:23:54.320248056 UTC entrypoint.bash[1]: Generating new ssh host keys
[...]
Feb 03 17:23:54.905471591 UTC entrypoint.bash[1]: Generating new ssh host keys: done
Feb 03 17:23:54.909569600 UTC entrypoint.bash[1]: Generating new ssh keypair for root
[...]
Feb 03 17:23:55.030312594 UTC entrypoint.bash[1]: Generating new ssh keypair for root: done
Feb 03 17:23:55.032226008 UTC entrypoint.bash[1]: Generating ~/authorized_keys
Feb 03 17:23:55.034103204 UTC entrypoint.bash[1]: INPUT_AUTHORIZED_GITHUB_USERS="johndoe,janedoe"
Feb 03 17:23:55.038587461 UTC entrypoint.bash[1]: Getting ssh key for GitHub user johndoe
Feb 03 17:23:55.417584683 UTC entrypoint.bash[1]: Getting ssh key for GitHub user johndoe: ssh-rsa AAAAB3[...]
Feb 03 17:23:55.420508431 UTC entrypoint.bash[1]: Adding ssh key for GitHub user johndoe to ~/authorized_keys
Feb 03 17:23:55.422960409 UTC entrypoint.bash[1]: Adding ssh key for GitHub user johndoe to ~/authorized_keys: done
Feb 03 17:23:55.822550877 UTC entrypoint.bash[1]: Getting ssh key for GitHub user janedoe: ssh-rsa AAAAB3[...]
Feb 03 17:23:55.825837633 UTC entrypoint.bash[1]: Adding ssh key for GitHub user janedoe to ~/authorized_keys
Feb 03 17:23:55.828350849 UTC entrypoint.bash[1]: Adding ssh key for GitHub user janedoe to ~/authorized_keys: done
Feb 03 17:23:55.830697946 UTC entrypoint.bash[1]: Generating ~/authorized_keys: done
Feb 03 17:23:55.833092469 UTC entrypoint.bash[1]: Checking if debugging is enabled
Feb 03 17:23:55.835331971 UTC entrypoint.bash[1]: Checking if debugging is enabled: no (INPUT_DEBUG="false")
Feb 03 17:23:55.837979973 UTC entrypoint.bash[1]: Creating new tmate session
Feb 03 17:23:55.840386401 UTC entrypoint.bash[1]: tmate version:
Feb 03 17:23:55.843086697 UTC entrypoint.bash[1]: tmate -V
tmate 2.4.0
Feb 03 17:23:55.846704385 UTC entrypoint.bash[1]: tmate -V returned 0
Feb 03 17:23:55.849116103 UTC entrypoint.bash[1]: tmate -S /tmp/tmate.sock -a /root/authorized_keys new-session -d
Feb 03 17:23:55.855401302 UTC entrypoint.bash[1]: tmate -S /tmp/tmate.sock -a /root/authorized_keys new-session -d returned 0
Feb 03 17:23:55.858183337 UTC entrypoint.bash[1]: tmate -S /tmp/tmate.sock wait tmate-ready
Feb 03 17:23:56.439357569 UTC entrypoint.bash[1]: tmate -S /tmp/tmate.sock wait tmate-ready returned 0
Feb 03 17:23:56.442387213 UTC entrypoint.bash[1]: Creating new tmate session: done
Connect to:
ssh shDNyU8Zp6quAGapbTK7Wtq9t@sfo2.tmate.io
Feb 03 17:23:56.446870550 UTC entrypoint.bash[1]: sleep 24h
```
