# From-scratch CentOS 4.9 Docker image

As-minimal-as-possible CentOS 4.9 image using `yum` and some `chroot` magic.
The idea of checking in a large, opaque binary file makes me itch, but the
Docker model doesn't currently allow for more control over image creation.  This
is hopefully the only time I'll have to do this…

Ok, this also contains the [EPEL](http://fedoraproject.org/wiki/EPEL) repo
configs.  But it's still pretty minimal.

Even so, it's too big to put into GitHub:

    remote: error: GH001: Large files detected.
    remote: error: Trace: 12b8141feda3e55a3296427b879875da
    remote: error: See http://git.io/iEPt8g for more information.
    remote: error: File centos49.tar.xz is 134.86 MB; this exceeds GitHub's file size limit of 100 MB

So, no automated builds.

## generating filesystem image

    docker run --privileged -i -t -v $PWD:/srv centos:centos6 /srv/build.sh

## machine architecture

Image archive filename contains architecture name now.
If you build your image on i386 machine(docker container), this script build centos4-32bit image.
I have only x86_64 and i686 machine, so I couldn't check on alpha, ia64, s390(x).

