================================================
  Check if your code follows kernel code style
================================================
.. _codestyle:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

The Linux kernel has a very clear and well-defined code style automated by a
tool named `checkpatch.pl`. You can use this script to check a file or a patch,
and it has a large number of options. Although this tool has powerful features,
it requires multiple parameters for different contexts, which can make it
tedious to use.

kw tries to deliver a unified development experience in the same way that it
provides a simple interface for developers to access some supported tools by
the kernel. For this reason, kw provides the ``kw codestyle <target>`` feature,
which will identify if the target is a folder, file, or patch with the same
command line. For example, you can point to a folder::

 kw codestyle drivers/gpu/drm/amd/display/amdgpu_dm/

or you can point it to a file::

 kw codestyle drivers/gpu/drm/amd/display/amdgpu_dm/amdgpu_dm.c

Using --start-line and --end-line options:
==========================================

The ``--start-line`` and ``--end-line`` options allow you to specify a range of 
lines in a file where you want to check for code style issues. This can be particularly
useful when you are only interested in checking a specific section of a file, rather
than the entire file.

Here is how to use these options:

To check the code style from a specific start line to the end of the file, use the
``--start-line`` option. For example, to start checking from line 50::

  kw codestyle --start-line 50 drivers/gpu/drm/amd/display/amdgpu_dm/amdgpu_dm.c

To check the code style from the beginning of the file up to a specific end line,
use the ``--end-line`` option. For example, to check up to line 100::

  kw codestyle --end-line 100 drivers/gpu/drm/amd/display/amdgpu_dm/amdgpu_dm.c

To check the code style within a specific range of lines, use both ``--start-line``
and ``--end-line`` options. For example, to check from line 50 to line 100::

  kw codestyle --start-line 50 --end-line 100 drivers/gpu/drm/amd/display/amdgpu_dm/amdgpu_dm.c

By using these options, you can focus your code style checks on specific parts of
your files, making it easier to identify and fix issues in targeted areas.

That is all you need to know about kernel code style checking under kw
management.
