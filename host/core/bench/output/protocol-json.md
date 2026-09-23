# Frame Protocol JSON admission

Canonical encoding and bounded, schema-validated decoding of the desired-state
document used by direct frame synchronization.


## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">N/A</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">18</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">N/A</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.20.4</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">29.1</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">3 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">1</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">1 s</td>
  </tr>
</table>

## Statistics



Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Deviation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">canonical encode desired state</td>
    <td style="white-space: nowrap; text-align: right">431.79 K</td>
    <td style="white-space: nowrap; text-align: right">2.32 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;321.02%</td>
    <td style="white-space: nowrap; text-align: right">2.04 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">4.08 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">decode and validate desired state</td>
    <td style="white-space: nowrap; text-align: right">222.54 K</td>
    <td style="white-space: nowrap; text-align: right">4.49 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;80.71%</td>
    <td style="white-space: nowrap; text-align: right">4.33 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">6.96 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">canonical encode desired state</td>
    <td style="white-space: nowrap;text-align: right">431.79 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">decode and validate desired state</td>
    <td style="white-space: nowrap; text-align: right">222.54 K</td>
    <td style="white-space: nowrap; text-align: right">1.94x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">canonical encode desired state</td>
    <td style="white-space: nowrap">4.14 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">decode and validate desired state</td>
    <td style="white-space: nowrap">9.68 KB</td>
    <td>2.34x</td>
  </tr>
</table>