<?php
//TODO: Add TRY clause around $_GET functions to trap warnings
$delete = $_GET["delete"];
$get = $_GET["get"];
$restore = $_GET['restore'];
$update = $_GET['update'];
$pos = $_GET['pos'];
$info = $_GET['info'];

if(!empty($info)) {
  if($info == 'sum')
  {
    $db = new SQLite3('../pvr.db');
    $results = $db->query('SELECT SUM(last_change) FROM recordings');
    $row = $results->fetchArray();
    print $row[0];
  }
  else
  {
    print "riban pvr<br>";
    exit(0);
  }
}

$db = new SQLite3('../pvr.db');
if(!empty($delete)) {
  $results = $db->query('UPDATE recordings SET status="delete" WHERE uri="' . $delete . '"');
}

if(!empty($restore)) {
  $results = $db->query('UPDATE recordings SET status="ready" WHERE uri="' . $restore . '"');
}

if(!empty($update)) {
  if(!empty($pos)) {
    $db->query('UPDATE recordings SET play_position=' . $pos . ' WHERE uri="' . $update . '"');
  }
}


if(!empty($get)) {
  $results = $db->query('SELECT * FROM recordings WHERE status="' . $get . '" ORDER BY title,season,episode,start');
  $j = '{ "recordings": [';
  while($row = $results->fetchArray()) {
    $j = $j . ' { "title" : "' . $row["title"];
    $j = $j . '", "uri": "' . $row["uri"];
    $j = $j . '", "format": "' . $row["format"];
    $j = $j . '", "summary": "' . $row["summary"];
    $j = $j . '", "description": "' . str_replace('"', '\'', $row["description"]);
    $j = $j . '", "icon": "' . $row["icon"];
    $j = $j . '", "quality": "' . $row["quality"];
    $j = $j . '", "position": "' . $row["play_position"];
    $j = $j . '" },';
  }
  $j = rtrim($j, ',') . ' ] }';
  print $j;
}
?>
