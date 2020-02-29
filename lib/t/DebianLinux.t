use strict;
use warnings;
use Test;
use Text::Glob ();

# Mock the glob function used in image_list()
my @glob_filenames;
BEGIN {
    no strict 'refs';

    *CORE::GLOBAL::glob = sub : prototype(_;) {
	if ($#glob_filenames >= 0) {
	    my $pattern = ($#_ >= 0 ? $_[0] : $_);
	    return Text::Glob::match_glob($pattern, @glob_filenames);
	} else {
	    return CORE::glob(@_);
	}
    }
}

use DebianLinux qw(version_cmp read_kernelimg_conf image_list);

BEGIN {
    plan test => 44;
}

## version_cmp

# Simple numeric comparison
ok(version_cmp('2', '2'), 0);
ok(version_cmp('2', '3'), -1);
ok(version_cmp('3', '2'), 1);
# Multiple components
ok(version_cmp('2.6.32', '2.6.32'), 0);
ok(version_cmp('2.6.32', '2.6.33'), -1);
ok(version_cmp('2.6.33', '2.6.32'), 1);
# Extra components (non-numeric, non-pre-release) > null
ok(version_cmp('2.6.32-local', '2.6.32-local'), 0);
ok(version_cmp('2.6.32', '2.6.32-local'), -1);
ok(version_cmp('2.6.32-local', '2.6.32'), 1);
# Extra numeric components > null
ok(version_cmp('2.6.32', '2.6.32.1'), -1);
ok(version_cmp('2.6.32.1', '2.6.32'), 1);
ok(version_cmp('2.6.32', '2.6.32-1'), -1);
ok(version_cmp('2.6.32-1', '2.6.32'), 1);
# Extra pre-release components < null
ok(version_cmp('2.6.33-rc1', '2.6.33-rc1'), 0);
ok(version_cmp('2.6.33-rc1', '2.6.33'), -1);
ok(version_cmp('2.6.33', '2.6.33-rc1'), 1);
ok(version_cmp('2.6.33-trunk', '2.6.33-trunk'), 0);
ok(version_cmp('2.6.33-rc1', '2.6.33-trunk'), -1);
ok(version_cmp('2.6.33-trunk', '2.6.33'), -1);
# Pre-release < numeric
ok(version_cmp('2.6.32-1', '2.6.32-trunk'), 1);
ok(version_cmp('2.6.32-trunk', '2.6.32-1'), -1);
# Pre-release < non-numeric non-pre-release
ok(version_cmp('2.6.32-local', '2.6.32-trunk'), 1);
ok(version_cmp('2.6.32-trunk', '2.6.32-local'), -1);
# Pre-release cases including flavour (#761614)
ok(version_cmp('2.6.33-trunk-flavour', '2.6.33-trunk-flavour'), 0);
ok(version_cmp('2.6.33-rc1', '2.6.33-trunk-flavour'), -1);
ok(version_cmp('2.6.33-rc1-flavour', '2.6.33-trunk-flavour'), -1);
ok(version_cmp('2.6.32-1-flavour', '2.6.32-trunk-flavour'), 1);
ok(version_cmp('2.6.32-trunk-flavour', '2.6.32-1-flavour'), -1);
ok(version_cmp('2.6.32-local', '2.6.32-trunk-flavour'), 1);
ok(version_cmp('2.6.32-trunk-flavour', '2.6.32-local'), -1);
# Numeric < non-numeric non-pre-release
ok(version_cmp('2.6.32-1', '2.6.32-local'), -1);
ok(version_cmp('2.6.32-local', '2.6.32-1'), 1);
# Hyphen < dot
ok(version_cmp('2.6.32-2', '2.6.32.1'), -1);
ok(version_cmp('2.6.32.1', '2.6.32-2'), 1);

## read_kernelimg_conf

sub read_kernelimg_conf_str {
    use File::Temp ();

    my $str = shift;

    my $fh = File::Temp->new() or die "$!";
    $fh->print($str) or die "$!";
    $fh->close();

    return read_kernelimg_conf($fh->filename);
}

sub hash_equal {
    my ($left, $right) = @_;

    # 'Smart equality' only compares keys
    return 0 unless %$left ~~ %$right;

    for my $key (keys(%$left)) {
	die "hash is too complex" unless (ref($left->{$key}) eq '' &&
					  ref($right->{$key}) eq '');
	return 0 unless $left->{$key} eq $right->{$key};
    }

    return 1;
}

# Empty config
ok(hash_equal(read_kernelimg_conf_str(''),
	      {
		  do_symlinks =>	1,
		  image_dest =>		'/',
	      }));
# Sample config
ok(hash_equal(read_kernelimg_conf_str(<< 'EOT'),
# This is a sample /etc/kernel-img.conf file
# See kernel-img.conf(5) for details

# If you want the symbolic link (or image, if move_image is set) to be
# stored elsewhere than / set this variable to the dir where you
# want the symbolic link.  Please note that this is not a Boolean
# variable.  This may be of help to loadlin users, who may set both
# this and move_image. Defaults to /. This can be used in conjunction
# with all above options except link_in_boot, which would not make
# sense.  (If both image_dest and link_in_boot are set, link_in_boot
# overrides).
image_dest = /

# This option manipulates the build link created by recent kernels. If
# the link is a dangling link, and if a the corresponding kernel
# headers appear to have been installed on the system, a new symlink
# shall be created to point to them.
#relink_build_link = YES

# If set, the preinst shall silently try to move /lib/modules/version
# out of the way if it is the same version as the image being
# installed. Use at your own risk.
#clobber_modules = NO

# If set, does not prompt to continue after a depmod problem in the
# postinstall script.  This facilitates automated installs, though it
# may mask a problem with the kernel image. A diag‐ nostic is still
# issued. This is unset be default.
# ignore_depmod_err = NO

# These setting are for legacy postinst scripts only. newer postinst
# scripts from the kenrel-package do not use them
do_symlinks = yes
do_bootloader = no
do_initrd=yes
link_in_boot=no
EOT
	      {
		  do_symlinks =>	1,
		  image_dest =>		'/',
	      }));
# Slightly different spacing and value syntax
ok(hash_equal(read_kernelimg_conf_str(<< 'EOT'),
image_dest = foo bar
	relink_build_link = yes
do_symlinks = 0    
    link_in_boot= false
no_symlinks=1
EOT
	      {
		  do_symlinks =>	0,
		  image_dest =>		'foo',
	      }));
# Check that 'false' and 'no' also work
ok(hash_equal(read_kernelimg_conf_str(<< 'EOT'),
do_symlinks = false
EOT
	      {
		  do_symlinks =>	0,
		  image_dest =>		'/',
	      }));
ok(hash_equal(read_kernelimg_conf_str(<< 'EOT'),
do_symlinks = no
EOT
	      {
		  do_symlinks =>	0,
		  image_dest =>		'/',
	      }));
# Check that invalid values have no effect
ok(hash_equal(read_kernelimg_conf_str(<< 'EOT'),
do_symlinks=
link_in_boot yes
link_in_boot 1
EOT
	      {
		  do_symlinks =>	1,
		  image_dest =>		'/',
	      }));
# Check link_in_boot dominates image_dest
ok(hash_equal(read_kernelimg_conf_str(<< 'EOT'),
image_dest = /local
link_in_boot = true
EOT
	      {
		  do_symlinks =>	1,
		  image_dest =>		'/boot',
	      }));

## image_list

@glob_filenames = qw(/boot/ipxe.efi /boot/initrd.img-4.19.0-4-amd64
    /boot/lost+found /boot/.. /boot/System.map-4.19.0-4-amd64
    /boot/config-4.19.0-3-amd64 /boot/vmlinuz-4.19.0-4-amd64
    /boot/initrd.img-4.19.0-3-amd64 /boot/grub
    /boot/vmlinuz-4.19.0-3-amd64 /boot/efi /boot/ipxe.lkrn
    /boot/. /boot/config-4.19.0-4-amd64
    /boot/System.map-4.19.0-3-amd64);
ok([image_list()] ~~
   [['4.19.0-4-amd64', '/boot/vmlinuz-4.19.0-4-amd64'],
    ['4.19.0-3-amd64', '/boot/vmlinuz-4.19.0-3-amd64']]);
@glob_filenames = qw(/boot/.. /boot/vmlinux /boot/vmlinux.old
    /boot/initrd.img-4.9.0-7-powerpc64le
    /boot/vmlinux-4.9.0-7-powerpc64le
    /boot/System.map-4.9.0-7-powerpc64le /boot/initrd.img.old
    /boot/System.map-4.9.0-6-powerpc64le /boot/.
    /boot/config-4.9.0-7-powerpc64le
    /boot/System.map-4.9.0-8-powerpc64le
    /boot/vmlinux-4.9.0-8-powerpc64le
    /boot/initrd.img-4.9.0-6-powerpc64le
    /boot/vmlinux-4.9.0-6-powerpc64le
    /boot/initrd.img-4.9.0-8-powerpc64le
    /boot/config-4.9.0-8-powerpc64le /boot/grub /boot/initrd.img
    /boot/config-4.9.0-6-powerpc64le);
ok([image_list()] ~~
   [['4.9.0-7-powerpc64le', '/boot/vmlinux-4.9.0-7-powerpc64le'],
    ['4.9.0-8-powerpc64le', '/boot/vmlinux-4.9.0-8-powerpc64le'],
    ['4.9.0-6-powerpc64le', '/boot/vmlinux-4.9.0-6-powerpc64le']]);
@glob_filenames = qw(/boot/vmlinux-4.19.0-3-m68k
    /boot/vmlinux-4.19.0-4-m68k /boot/vmlinuz-4.1.0-2-m68k
    /boot/config-4.19.0-3-m68k /boot/config-4.19.0-4-m68k
    /boot/config-4.1.0-2-m68k /boot/initrd.img-4.19.0-3-m68k
    /boot/initrd.img-4.19.0-4-m68k /boot/initrd.img-4.1.0-2-m68k
    /boot/System.map-4.19.0-3-m68k /boot/System.map-4.19.0-4-m68k
    /boot/System.map-4.1.0-2-m68k);
ok([image_list()] ~~
   [['4.19.0-3-m68k', '/boot/vmlinux-4.19.0-3-m68k'],
    ['4.19.0-4-m68k', '/boot/vmlinux-4.19.0-4-m68k'],
    ['4.1.0-2-m68k', '/boot/vmlinuz-4.1.0-2-m68k']]);

# Disable mocking
@glob_filenames = ();
