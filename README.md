# BTC Whaling

![MobyDick.jpg](https://songazine.fr/v2/wp-content/uploads/2019/12/moby-dick-pix-720x406.jpg)

This is a simple project that extract the biggest account in the `blockchain`
and tries to find the private key.

> Disclaimer: This is a project for fun and learning. Even with the biggest
> compute power, you won't be close to finding a key. That being said,
> there is still a chance.

![There_is_a_chance.gif](https://i.giphy.com/media/8vDbvPMP3tGF2/giphy.gif)


## Dependencies

You need to have an `Unspend Transaction Database` (`chainstate` folder of `bitcoind`).
Because of the size of such a database, it cannot be included in the project.
To create one, simple run `bitcoind` and wait until the `blockchain` is complete.

The project uses two binaries to extract and crack the keys.
  - [`bitcoin-utxo-dump`](https://github.com/in3rsha/bitcoin-utxo-dump) which can be in the `PATH`, or will be downloaded and build if `go` is available
  - [`VanitySearch`](https://github.com/JeanLucPons/VanitySearch) which should be in the `PATH`

Optionnaly, `pv` is recommended to display progression.

Each dependencies can be manually located using their respective environment variables:
  - `BITCOIN_UTXO_DUMP` (or `GO`)
  - `VANITYSEARCH`


## Usage

This project uses a `Makefile` to issue command.
If all requirements are met, a simple `make run` should be enough.

Use `make help` to see available commands.

> Notice: Some steps will check the requirements before proceeding,
> so you can safely try any target.

First run will take some times as it create the initial files, 
but next runs will start immediatly.

By default, the project will work in the current folder and create files named `utxodump.*`.
You can override this by renaming environment variables `FILE_PREFIX`. 
To rename a specific file, have a look at available variables in the head of the `Makefile`.

Default `Satoshis` minimal amount is `1000000`. You can also configure that with an 
environment variable named `MIN_SATOSHIS`.


## Examples

```
$ UTXO_DIR=bitcoind/chainstate
> MIN_SATOSHIS=9999999
> FILE_PREFIX=demo
> BITCOIN_UTXO_DUMP=../bitcoin-utxo-dump
> VANITYSEARCH=../VanitySearch.exe
> make run
[...]
66500000 utxos processed

Total UTXOs: 66558899
Total BTC:   18461444.35820543
2.55GiB 0:03:43 [11.7MiB/s] [=======================================================================>] 100%
 529MiB 0:00:35 [14.9MiB/s] [=======================================================================>] 100%
 529MiB 0:03:01 [2.91MiB/s] [=======================================================================>] 100%
 502MiB 0:02:21 [3.54MiB/s] [=======================================================================>] 100%
[Loading input file 100.0%]
VanitySearch v1.19
[Building lookup16 100.0%]
[Building lookup32 100.0%]
Search: 7246411 addresses (Lookup size 65536,[43,12550]) [Compressed]
Start Fri Aug 21 14:16:14 2020
Base Key: 719E1E8147DBABBED26CC564E715212AE52029EDC5ACB8DE36B2F79AF16A5B04
Number of CPU thread: 11
GPU: GPU #0 GeForce GTX 2080 (40x128 cores) Grid(320x128)

[189.80 Mkey/s][GPU 336.11 Mkey/s][Total 2^37.45][Prob 0.0%][50% in 2.29772e+32y][Found 0]
```

