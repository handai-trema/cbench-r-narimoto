#課題レポート(cbenchの高速化)  
更新日：(2016.10.17)  

###課題：  
```
課題内容：
RubyのプロファイラでCbenchのボトルネックを解析する．    
```

ruby-profを用いてプロファイリングを行った．  
プロファイリングの全結果は[log.txt](https://github.com/handai-trema/cbench-r-narimoto/blob/master/log.txt)を参照されたい．  
ここでは，実行時間割合（%self）の上位１０個を示す．
```
%self      total      self      wait     child     calls  name
 2.35      9.089     3.030     0.000     6.058   338270  *BinData::BasePrimitive#_value
 2.17      4.283     2.798     0.000     1.484   179579   Kernel#initialize_clone
 2.13     31.279     2.745     0.000    28.534   173907   BinData::Base#new
 2.04      2.696     2.626     0.000     0.070   557334   Kernel#respond_to?
 1.93      6.959     2.487     0.000     4.472   179579   Kernel#clone
 1.88      7.428     2.423     0.000     5.005   290065  *BinData::BasePrimitive#snapshot
 1.82     28.611     2.351     0.000    26.260   154051   BinData::Struct#instantiate_obj_at
 1.82      2.346     2.346     0.000     0.000   186044   BasicObject#!
 1.61      2.232     2.072     0.000     0.160   217460   BinData::Base#get_parameter
 1.60      3.020     2.066     0.000     0.953   223863   Kernel#define_singleton_method
```
プリミティブ型（BasePrimitive#）関連の処理や，オブジェクトのクローン関連の処理などが見られる．
その中で，３位に位置しているBinData::Base#newに注目する．
cbench.rbを見てみると，次のような記述となっている．
```
def packet_in(datapath_id, message)
  send_flow_mod_add(
    datapath_id,
    match: ExactMatch.new(message),
    buffer_id: message.buffer_id,
    actions: SendOutPort.new(message.in_port + 1)
  )
end
```
packet_inが発生するたびにmatch:とactions:においてnewが実行されていることがわかる．
よって，cbench.rbにおける実行時のボトルネックはこのnewである．  

###発展課題：  
```
課題内容：
cbenchの高速化
```
前述より，packet_in\(\)におけるnewの実行がボトルネックになっていることがわかっているため，
これを解決する必要がある．packet_inが発生する度に新たにflow_modメッセージを作りなおしていることが非効率の原因であると考える．
[テキスト](http://yasuhito.github.io/trema-book/#cbench)によると，cbenchにおけるpacket_inのメッセージは毎回同じであるとのことなので，最初に生成したflow_modメッセージをキャッシュし，以降はそのメッセージを再利用するように改良した．  
改良したcbenchにおけるruby-profによるプロファイリング結果\([log_fast.txt](https://github.com/handai-trema/cbench-r-narimoto/blob/master/log_fast.txt)\)の上位１０個を以下に示す．
```
%self      total      self      wait     child     calls  name
3.59      4.650     4.507     0.000     0.144   355122   BinData::Base#get_parameter
2.83      5.867     3.548     0.000     2.319   334332   Kernel#define_singleton_method
2.10     30.514     2.632     0.000    27.882   194828   BinData::SanitizedField#instantiate
2.03     27.885     2.553     0.000    25.333   194969   BinData::SanitizedPrototype#instantiate
1.98      2.480     2.480     0.000     0.000   194983   Kernel#initialize_copy
1.85      2.319     2.319     0.000     0.000   334333   BasicObject#singleton_method_added
1.81      2.269     2.269     0.000     0.000   194828   Array#[]=
1.74     34.027     2.185     0.000    31.842   180903  *BinData::BasePrimitive#do_read
1.71      2.671     2.150     0.000     0.521   139163   StringIO#read
1.66      8.845     2.085     0.000     6.760   139155   BinData::IO::Read#read
```
結果より，改良前の上位１０個から大きく異なっていることがわかる．
つまり，BinData::BasePrimitive#やKernel#cloneなども，flow_modメッセージの生成時に呼び出されていたものだということがわかった．また，cbench実行時に表示される結果を以下に示す．
```
(改良前)
1   switches: fmods/sec:  1892   total = 0.189188 per ms
1   switches: fmods/sec:  1883   total = 0.188247 per ms
1   switches: fmods/sec:  2032   total = 0.203161 per ms
1   switches: fmods/sec:  1855   total = 0.185449 per ms
1   switches: fmods/sec:  2025   total = 0.202455 per ms
1   switches: fmods/sec:  1545   total = 0.154477 per ms
1   switches: fmods/sec:  1746   total = 0.174540 per ms
1   switches: fmods/sec:  1621   total = 0.162012 per ms
1   switches: fmods/sec:  1233   total = 0.123207 per ms
1   switches: fmods/sec:  1723   total = 0.172263 per ms
RESULT: 1 switches 9 tests min/max/avg/stdev = 123.21/203.16/173.98/23.81 responses/s

(改良後)
1   switches: fmods/sec:  17191   total = 1.713990 per ms
1   switches: fmods/sec:  16504   total = 1.650322 per ms
1   switches: fmods/sec:  17801   total = 1.780057 per ms
1   switches: fmods/sec:  16038   total = 1.603731 per ms
1   switches: fmods/sec:  17646   total = 1.759663 per ms
1   switches: fmods/sec:  15800   total = 1.579945 per ms
1   switches: fmods/sec:  17482   total = 1.748115 per ms
1   switches: fmods/sec:  15419   total = 1.541888 per ms
1   switches: fmods/sec:  15906   total = 1.590537 per ms
1   switches: fmods/sec:  15312   total = 1.531166 per ms
RESULT: 1 switches 9 tests min/max/avg/stdev = 1531.17/1780.06/1642.82/90.98 responses/s
```
flow_modメッセージの送信速度が約10倍程度向上していることがわかる．

##ソースコード  
[cbench_fast.rb（高速化後）](https://github.com/handai-trema/hello-trema-r-narimoto/blob/master/lib/cbench_fast.rb)

##プロファイリング結果
[log.txt（高速化前）](https://github.com/handai-trema/cbench-r-narimoto/blob/master/log.txt)  
[log_fast.txt（高速化後）](https://github.com/handai-trema/cbench-r-narimoto/blob/master/log_fast.txt)
