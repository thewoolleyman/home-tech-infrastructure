A summary of the video's content is provided below, followed by the full transcript.

### Summary

The video introduces the Tailscale Kubernetes Operator and its three main features: an API proxy for identity-based cluster access, ingress for automatic TLS certificate management, and egress/cross-cluster connectivity. The speaker then demonstrates how to set up a self-hosted Kubernetes cluster using Talos Linux, an immutable, API-driven operating system. He explains that Talos nodes are configured remotely via API calls rather than traditional methods like SSH. The tutorial walks through creating a single-node Talos cluster on Proxmox, generating the necessary configuration files, and bootstrapping the cluster. Afterward, he installs the Tailscale Kubernetes operator using a Helm chart and configures it with OAuth credentials. Finally, he demonstrates the API proxy feature by using his Tailscale identity to securely access the Kubernetes cluster with `kubectl`, eliminating the need for manual kubeconfig management.

### Transcript

[00:00 - 00:12] A couple of weeks ago, the Tailscale team were at KubeCon in Atlanta, and they were kind of surprised by how few of you knew that Tailscale has a Kubernetes operator. So, now you know, but what does it do?

[00:12 - 00:28] Well, it has three main pillars. The first of which is the API proxy. This API proxy basically means that you never have to log into your Kubernetes cluster ever again manually. It reuses the identity of your Tailnet connection to automatically log you into your cluster.

[00:28 - 00:47] Second is ingress, so you can use Tailscale to automatically provision TLS certificates on your Tailnet. So you don't have to worry about some other cert manager process or something else going on in Kubernetes. There's also egress and also cross-cluster, sort of multi-cluster connections between different clusters on your Tailnet.

[00:47 - 01:09] And I think one of the more interesting things about this is it's completely agnostic of the Kubernetes cluster provider underneath. So the team were like, Alex, we're going to get you to spin up clusters on EKS and Google Cloud and everybody that offers hosted Kubernetes solutions these days. But you know me by now, I like to self-host as much as I possibly can.

[01:09 - 01:17] So, enter Talos Linux. This is the Kubernetes operating system. It's just Linux, but it's Linux like you've never seen before.

[01:18 - 01:22] (Tailscale logo animation)

[01:22 - 01:42] So what do I mean by that? Linux like you've never seen before. Well, typically with Linux, you would install the image from an ISO, and then you would boot into it, and then you'd run a bunch of Ansible scripts or something to configure that Linux box and convert it into whatever role that that box was going to fulfill for you and your organization or in your home lab.

[01:42 - 02:02] With Talos, though, it's completely API-driven. And this is really quite a a paradigm shift. It's a big mental model shift in your head. Because these machines boot up and they have absolutely no idea what their purpose in life is.

[02:02 - 02:39] The ISO is just completely plain. It's got everything it needs to spin up a kubelet, um, some basic Linux kernel parameters compiled in. Uh, essentially, it's got everything it needs to be a Kubernetes control plane node or a worker, but it doesn't know anything about how to connect to the other nodes in your network, if they even exist, or really anything much about the world at all. So what we have to do is via the API that this node exposes, we have to connect in using a tool called talosctl and remotely configure and provide configuration files to those remote nodes in order to tell them, well, what their purpose in life is.

[02:39 - 02:43] (Rick and Morty clip)
Robot: What is my purpose?
Rick: You pass butter.

[02:44 - 03:09] And so this means that you can destroy a node and bring it back up and then reapply a config from a different node 20 minutes ago with no persistent state whatsoever, and it will just come back up and think, you know, it's it's the ultimate culmination of the cattle versus pets discussion in the Kubernetes universe that's been going on for the last decade or so, I think, since CoreOS was born sort of 2015 era.

[03:09 - 03:33] Now, the Talos project has a fantastic getting started guide here by Justin Garrison over on YouTube. Highly recommend you go and watch that. But also, they have uh, really some pretty great documentation here. So what I thought we'd do in today's video is spin up a really basic single-node Kubernetes cluster using Talos on top of Proxmox and then install the Tailscale operator and show you that you never even need to log into this thing.

[03:33 - 03:54] There's no kubeconfig files. I mean, they do exist technically, but uh, the API proxy part of the Tailscale operator transparently maps to cluster roles under the hood so that you can log in as a system admin or any other RBAC user or profile that you've created in your cluster.

[03:54 - 04:12] So that's what we're showing in today's video, and there'll be chapters down below if you want to jump around. Uh, you know, if you've already got a working Talos VM or you don't even care about spinning up your own Talos stuff, then you can just skip to the next chapter or two where we just configure the operator instead.

[04:12 - 04:30] Now, I'm going to do this today on the little Dell 1-liter PC that's in the rack just down there behind me. You really don't need much to get started. And Talos will run on bare metal as well. So if you want to completely take Proxmox out of this equation, you absolutely can do. However, whilst you're learning, certainly I found in the last week or two that I'm spinning these things up, I'm destroying them, and I'm kind of making mistakes.

[04:30 - 04:42] And that's much easier to do in a virtual machine and get the concepts square in your head and then move on to the bare metal later on, which will be coming as a separate video series in the channel because just there, that little blinky red light, that is a three-node Lenovo M720Q Kubernetes cluster.

[04:42 - 04:55] (On-screen text: Kube Kubernetes cluster)
Kube Kubernetes.

[04:55 - 05:19] So, we need to first of all download our Talos Linux image from their image factory. And these are a bunch of pre-baked images that contain a few useful utilities, to be honest. So, let's say you wanted to do some hardware acceleration, you wanted to run a Jellyfin or something inside this cluster. Well, you're going to need Intel GPU drivers. Or let's say you want to do some local self-hosted AI with an Nvidia GPU, well, you're going to need the Nvidia drivers. These image factories contain all of those little bits and bobs inside the images.

[05:19 - 05:35] So, I see no reason to do anything other than the latest right now. So I'm going to do that, 1.11.5, and I'm going to scroll down and look for, where is it? Proxmox, is it here? Yeah, there we go. Nocloud.

[05:35 - 06:03] So, you see how Talos is designed to run and has it has a bunch of optimizations, presumably in the kernel they've compiled for all of these different providers. You know, like Amazon famously runs on Xen. Some of these other guys run on Linux KVM. That kind of optimization. All right, so we're going to just do the nocloud option right here. Click on next. AMD64 is fine. I don't need secure boot for a virtual machine, although if you need it, that option is there.

[06:03 - 06:24] Now, in terms of system extensions, I actually started off making this video series with Tailscale installed, but if you do that, you're going to run into some kind of clashes in the networking side of things later on. So, as tempting as it might be for me to put Tailscale in every base image on everything on the planet, I'm actually not going to do that today.

[06:24 - 06:48] What I do need, though, are these QEMU guest agent utilities. So I'm going to select that. And this is so that Proxmox can actually communicate with the virtual machine properly. It will be able to get things like the IP address of the virtual machine. It will be able to do things like, um, giving it graceful startup and shutdown procedures, and it's just going to make for a better experience overall.

[06:48 - 07:03] So, have a look at this list of system extensions. They are quite extensive. You know, maybe you need, I don't know, there's the i915, for example, uh, for the Intel drivers, that kind of thing. So, all we need right now are the QEMU guest drivers.

[07:03 - 07:13] I don't need any other kernel customizations. That's totally fine. So you can see there are lots of different options here, and you can use this to feed into any of your config management systems. In fact, there's a tool called talhelper, which, uh, essentially allows you to automate the process of creating Talos, um, virtual machines and even bare metal configurations as well.

[07:13 - 07:38] It's very helpful when you want to put this stuff in source control and encrypt secrets and all that kind of stuff. We'll come on to that later. Don't worry about that. But for now, all we want to do is download this ISO right here. Once the ISO is downloaded, the next step is to go to your Proxmox, wherever you store your ISO images, and just upload that image. I'm actually going to just get the URL of the image rather than uploading the ISO directly.

[07:38 - 08:06] I'm going to download it from a URL instead and download that to my Proxmox instance that way. Now, once this is finished downloading, we're going to create the virtual machine and then install Talos inside that. Okay, download complete. Now we want to create a virtual machine. So let's do this. Let's give it a number of, I don't know, 1111. And I'm going to do Talos 1.

[08:06 - 08:27] At the moment, I think I'm just going to do a single-node cluster, but typically it's it's good to have, I don't know, like Talos worker 1, because if you have multiple virtual machines to run as worker nodes, whatever, it's just good to have that naming. However, for now, Talos 1 will do us just fine. All right, so the ISO is nocloud.

[08:27 - 08:38] System, I'm going to leave all of this as default except for QEMU agent, which remember we added to the ISO a few minutes ago.

[08:38 - 08:58] Disks, uh, sure, 64, why not? SCSI. Yep, that should all be fine for our purposes. Cores, four, yep. Memory, I'm going to give it 8 gig because, well, actually, I'm going to give it 16. That's probably way overkill, but that will do just fine. And then the network, all right, let's start after created.

[08:58 - 09:08] I think that's all we need to do. Creating the VM is really the easiest part of this whole process. And you can see in the console, now it's picked up the ISO and it's going to boot from that ISO. And so once it's booted, how do we interact with this thing?

[09:08 - 09:22] We can't SSH into it. We can't go over it. We can't go under it. We we can't even go through it, right? So, how do we interact with it? Well, we use talosctl to do that.

[09:22 - 09:37] Now, this command is, well, it's first of all, it's really got a very extensive help section built right into it. But let's just say we wanted to understand what the disk layout on our remote node looks like. So, first of all, we have to get the IP address of that remote node.

[09:37 - 09:53] So, we do that by going here and looking at the console, 192.168.1.194. And because we have the QEMU guest tools installed, that will also show in our Proxmox console just here as well. So, what we can do is we can construct a command like this.

[09:53 - 10:13] `talosctl get disks`, and then we have to pass in `--insecure`. That's because this node is, it's not bootstrapped, so it doesn't have any certificates generated at this point. It's just, remember, it's just a completely, it's a butter robot. It doesn't know what its purpose is, okay? So then we pass in the IP address, and you can see that it prints out a pretty handy-dandy little table of all the different disks that this virtual machine can see.

[10:13 - 10:41] You recognize some very basic stuff here like `sda`. On a Linux box, this would be sort of like `/dev/sda`, like you would see in an fstab or something like that. So we know that these virtual disks exist within inside the system. So what we can do now is we can generate a Talos config to pass to that node. Again, we'll pass the config using the API to that remote node over the network and tell it what its purpose in life is.

[10:41 - 11:14] Now, a really interesting thing about Talos is that it actually runs out of RAM. So you can boot from this ISO and then pull the USB stick or pull the ISO out of the machine, depending whether it's a virtual machine or a physical machine, and Talos basically bootstraps itself into memory and then kexecs itself into existence. It's a very, very cool system. So let's jump back to the Talos documentation for just a second.

[11:14 - 11:27] We've downloaded our Talos ISO, we've booted our machine. We now need to store our IP address into an environment variable. So I'm going to go ahead and do that. I'm going to export this control plane IP.

[11:27 - 11:45] Was it 192.168.1.194? And so this is going to create what's called an environment variable in my shell. So if I do `echo` now, `CONTROL_PLANE_IP`, it prints that out, and it means we can use that value in scripts, which we're about to use with Talos.

[11:45 - 12:00] So, going back to the getting started, we're only going to have one node, so I'm not going to do the control plane and worker thing, just literally got one node. Now, I don't actually want to do any static IP configurations. I want this to all be completely DHCP.

[12:00 - 12:28] So, luckily, the leases in my router will last for a few hours, but just bear in mind that you might want to set a static IP reservation based on the MAC address of this node in your router so that it gets a, it gets a static IP, but it's configured, well, it gets a, it gets a DHCP IP, I should say, but it's statically mapped inside your router software using the MAC address.

[12:28 - 12:40] So, you don't need to provide static IP configuration to the virtual machine or the bare metal node, but it still gets a stable IP within your network. Okay, now the next step is to learn about our installation disks.

[12:40 - 12:51] And hey, look, it's our old friend, `talosctl get disks`. And this time, because we have the control plane IP set as an environment variable, we can actually see what's going on a bit more easily. So, if I'm going to run this one more time, we can see that `sda` is going to be our install target.

[12:51 - 13:08] So, now we're going to actually generate our cluster configuration completely manually. I'm going to have a video next week or it might be January, honestly, but, um, I'm going to have a video where we go through a bunch of Terraform and OpenTofu code that I've written to automate this process using talhelper command and Terraform code as well.

[13:08 - 13:27] All right, so let's give ourselves a cluster name of, I always like Bob. I don't know why, but I do. And then the disk name, so that's going to be `/dev/sda` or is it, yeah, okay. So the install disk, we have to put in, oh no, so the environment variable is just `sda`.

[13:27 - 13:43] Okay, that's a little confusing, but we'll get there, we'll make it work. We're going to take this value from here. So we know that this 69 gigabyte disk is what we're going to use to install Talos onto. It's just the boot volume, it's where `/var/lib` and all our cube, you know, our containers will live. This is the node storage itself.

[13:43 - 14:08] In terms of stateful storage for your pods and things like that, that could live on here if you want to do like host path mapping and, just don't do that. Use Ceph, use NFS, use literally anything else other than a host path map. However, this is only a single node cluster, so it might actually not be that big of a deal. But anyway, storage is a whole other conversation that's not part of this video.

[14:08 - 14:25] Okay, so now we, now we've created our cluster name and our disk name, I'm going to run this command of `talosctl gen config`. Cluster name. But first, I'm just going to make a directory here called `bob`. I'm going to change into that `bob` directory. And now I'm going to run my `gen config` command.

[14:25 - 14:52] So, we're going to ingest our cluster name variable that we set. We're going to ingest our control plane IP variable that we set, along with `sda` for the install target disk as well. And now you'll see that there's a few files being created as part of this process. In fact, let me bring up VS Code, that might be the easiest way to show you what's going on here.

[14:52 - 15:22] So these three commands, these three files, sorry, govern exactly what your Talos cluster is going to look like. So you've got a, it's a very, very long YAML file. I think it's about 500 lines or so, just for the control plane. There you go, 552 lines actually. But it governs everything that this node is going to do.

[15:22 - 15:31] So it turns this from a boring old plain virtual machine into a butter robot, or in this case, a control plane node.

[15:31 - 15:48] Now, we're not actually going to use the worker config for an example today, but again, this would configure everything that needs to be configured as it pertains to being a worker node within your cluster. You can see we've got things like the certificate authority that's being configured here, the root CA, and all of these certificates live in here.

[15:48 - 16:01] So you might want to, if you're going to commit this to source control, use something like SOPS to encrypt those, those values. But again, we'll come on to that in our automation video later on in this sort of Kubernetes for beginners series. All right, so we have our three files from this command.

[16:01 - 16:15] We have the control plane, the worker, and the config. Now it's time to actually apply that configuration. So, first thing that they have us do in step seven is apply the `controlplane.yaml` to our remote, well, control plane node. I say it's only a one-node cluster as I keep saying, but we're going to apply that config.

[16:15 - 16:41] Again, using the insecure, self-generated certificate that the, that this node generates for its own API right now. And then we're going to apply that YAML file to that remote node. I'm going to jump real quick over to the console of this node because what you're going to notice is in the background, this thing is now starting to install itself. Look, stage installing over here. This will take five, maybe 10 minutes depending on the speed of your internet connection and the performance available to this specific node.

[16:41 - 17:04] I've noticed that there are quite a few errors scroll by in the console. You think, you see things like error evaluating disk locator. Don't worry too much about that. There's a, there's a bunch of what I think, they're not necessarily bugs, they're just like race conditions in terms of things being done that expect other things to be done at the same time or are in process of being done.

[17:04 - 17:29] It does always, almost always seem to figure itself out. So try not to worry too much and just be patient. This node will reboot itself. It will re-kexec and re-bootstrap itself once it's finished installing. And then you'll notice that things like the stage here goes from installing to being ready, and then the kubelet will be ready and all that stuff, it will figure itself out. But like I say, it takes maybe five to 10 minutes.

[17:29 - 17:57] The node just rebooted. It didn't go all the way back to the BIOS. It just closed down its virtual RAM environment version of itself and then re-kexec'd into the newly installed version of itself. This is so cool. This is so cool. And now you can see that the stage of the install process has changed from installing to booting over here. And we can see the cluster name of Bob is here. It's only got one machine in it, and the kubelet is healthy.

[17:57 - 18:16] Now, what you want to look for is this message right here where it says, "etcd is waiting to join the cluster." This is where we go back to the Talos documentation. We need to set our endpoints for talosctl, and we're going to do that just by copying this command right here, where we ingest the talosconfig that we generated in the previous step, and it's going to set the endpoints for talosctl.

[18:16 - 18:39] So this is how it knows to communicate with the endpoints inside your cluster. The next thing, and this is really important that you only do this once on a single control plane node, as they, as they document right here, we're going to bootstrap etcd, just with this one command. This is how easy it is with Talos.

[18:39 - 19:03] We just do one command, it bootstraps etcd, and within a couple of minutes, we have a fully working cluster. It's actually kind of amazing. So, how do we verify that that step succeeded? Well, we need to use talosctl. I hope you're getting the picture by now. You don't connect to these nodes and go on the terminal and type stuff and, it's all done remotely through the API.

[19:03 - 19:20] So as long as you know this IP address and you set up your endpoints in your talosconfig, you're good to go. So what we need to do is export this variable here called `TALOSCONFIG`, and we're going to set this to the path in our directory here where the talosconfig file lives, which is actually just literally right here in this directory.

[19:20 - 19:43] So, `export TALOSCONFIG=./talosconfig`. And now hopefully, when we do a `talosctl config info`, it can connect to our remote cluster and tell us what's going on. So let's now run a `talosctl health` command. I'm going to pass in the control plane IP of the node.

[19:43 - 20:14] And we can see that all of the various checks that the health command here is doing are present and correct. So, let's grab our kubeconfig next and actually connect into Kubernetes properly. I'm going to do this one here where I specify a specific file name because once we've got Tailscale operator installed, we're not actually going to need our kubeconfig ever again.

[20:14 - 20:31] So let's just run this command here, `tailscale kubeconfig alternative-kubeconfig`. And this is going to go to the cluster, grab the kubeconfig to our local machine. And then I'm going to export this environment variable here to my cluster so I can now, to my local laptop, sorry.

[20:31 - 20:52] So I can now run things like `kubectl get nodes`. In fact, let me resize this window because I had a bit of feedback from somebody a couple of weeks ago that once it gets to the bottom of the screen, they, they can't see what I'm doing. So, we're going to do `kubectl