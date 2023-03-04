<?php
$myFile = "dump.txt";
$fh = fopen($myFile, 'w') or die("can't open file");
$stringData = $_REQUEST;
fwrite($fh, print_r($stringData,true));
fwrite($fh, "hello\nworld\n");
fclose($fh);
?>

