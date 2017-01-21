# Testing Pachyderm with very large files

This is a test case for [Pachyderm][] focusing on large files and commits,
and avoiding the use of `BLOCK` mode.  It uses data from the [OPUS][]
project, which is a collection of multi-lingual texts that have been
"aligned" at the sentence level.  Total data size roughly 60 GB at moment,
including a single 33 GB input file.

For more information on where the data comes from and how to transfer it to
S3, see [data/README.md](./data/README.md).  For the moment, we provide a
version of the data in `us-east-1`.

OPUS is a great data set for all sorts of linguistics and translation
tasks, though you usually need to massage into a more useful format for
your specific application first.

## Cluster configuration

Kubernetes master and two minions, each with the following specs:

- Docker: 1.12.3
- OS: RancherOS v0.7.1 (4.4.24)
- CPU: 2x2.49 GHz
- RAM: 7.3 GiB
- Disk: 469 GiB

This cluster was created using Rancher 1.3.2, with the fix for
rancher/rancher#7370 applied.  The servers were created using the Rancher
REST API using the following options:

```typescript
  const config = {
    amazonec2Config: {
      accessKey: process.env['RANCHER_AWS_ACCESS_KEY_ID'],
      ami: 'ami-dfdff3c8',
      deviceName: '/dev/sda1',
      iamInstanceProfile: 'kubernetes',
      instanceType: 'm3.large',
      // Allocate a public address so the servers can easily
      // access outside resources (like Docker Hub).
      privateAddressOnly: false,
      region: 'us-east-1',
      retries: '5',
      rootSize: '500',
      secretKey: process.env['RANCHER_AWS_SECRET_ACCESS_KEY'],
      securityGroup: ['rancher-machine'],
      spotPrice: '0.50',
      sshUser: 'rancher',
      subnetId: '...',
      // Never use public addresses to communicate with servers,
      // because the security group will block most of it.
      usePrivateAddress: true,
      volumeType: 'gp2',
      vpcId: '...',
      zone: 'a'
    },
```

Hosts can also be added manually using the UI and these options.  For
testing purposes, you can set up the instance profile `kubernetes` with EBS
attach/detach permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:DetachVolume"
      ],
      "Resource": "arn:aws:ec2:us-east-1:YOUR-AWS-ID-HERE:instance/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:DetachVolume"
      ],
      "Resource": "arn:aws:ec2:us-east-1:YOUR-AWS-ID-HERE:volume/*"
    }
  ]
}
```

...and you can allow Rancher to create the `rancher-machine` security group
when creating a server through the UI.

## Test 1: Commiting a large file via S3 URL

This is a 33GB tarball stored on S3.

```sh
pachctl create-repo eubookshop_s3
pachctl put-file eubookshop_s3 master EUbookshop0.2.tar.gz -c \
    -f s3://fdy-pachyderm-public-test-data/opus/EUbookshop0.2.tar.gz
```

**Result in local test:** The ingestion hung for a while and returned:

```
read tcp 10.42.131.61:55858->52.216.226.112:443: read: connection reset by peer
```

It looks like `pachd` and `rethinkdb` may have broken:

```
$ kubectl get all
NAME               READY     STATUS              RESTARTS   AGE
po/etcd-4h30v      1/1       Running             0          1d
po/pachd-dn1b6     0/1       Error               4          2m
po/pachd-k8v2f     1/1       Unknown             7          1d
po/rethink-11szv   0/1       ContainerCreating   0          2m
po/rethink-mfjvn   1/1       Unknown             0          1d

NAME         DESIRED   CURRENT   READY     AGE
rc/etcd      1         1         1         1d
rc/pachd     1         1         0         1d
rc/rethink   1         1         0         1d

NAME             CLUSTER-IP     EXTERNAL-IP   PORT(S)                                          AGE
svc/etcd         10.43.8.144    <none>        2379/TCP,2380/TCP                                1d
svc/kubernetes   10.43.0.1      <none>        443/TCP                                          1d
svc/pachd        10.43.37.253   <nodes>       650:30650/TCP,651:30651/TCP                      1d
svc/rethink      10.43.23.240   <nodes>       8080:32080/TCP,28015:32081/TCP,29015:30438/TCP   1d

NAME              DESIRED   SUCCESSFUL   AGE
jobs/pachd-init   1         1            1d
```

Neither of the minions appears to be particularly low on disk space:

```
root@5a7c7b3ebed6:/# df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay         469G   65G  384G  15% /
tmpfs           3.7G     0  3.7G   0% /dev
tmpfs           3.7G     0  3.7G   0% /sys/fs/cgroup
/dev/xvda1      469G   65G  384G  15% /.r
shm              64M     0   64M   0% /dev/shm
```

```
root@b8363e1a9fc6:/# df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay         469G  4.9G  444G   2% /
tmpfs           3.7G     0  3.7G   0% /dev
tmpfs           3.7G     0  3.7G   0% /sys/fs/cgroup
/dev/xvda1      469G  4.9G  444G   2% /.r
shm              64M     0   64M   0% /dev/shm
```

## Test 2: Commiting a large file via HTTP URL

This is similar to the above, except we use a explicit URL.  In practice,
this URL might be signed using `aws s3 presign`.

```
pachctl create-repo eubookshop_http
pachctl put-file eubookshop_http master EUbookshop0.2.tar.gz -c \
    -f https://fdy-pachyderm-public-test-data.s3.amazonaws.com/opus/EUbookshop0.2.tar.gz
```

[Pachyderm]: https://www.pachyderm.io/
[OPUS]: http://opus.lingfil.uu.se/index.php
