<?php

$delete_period = 3 * 60 * 60 * 24;
$db = new SQLite3('../pvr.db');

$threshold = time() - $delete_period;

$results = $db->query('SELECT uri,title FROM recordings WHERE status="delete" AND last_update < ' . $threshold);

while($row = $results->fetchArray()) {
  try {
    unlink('../' . $row["uri"]);
  } catch (Exception $e) {
    printf("Unable to delete file %s\n", $row['uri']);
  }
  $db->query('DELETE FROM recordings WHERE uri="' . $row['uri'] . '"');
  printf("Deleted %s\n", $row['title']);
}
?>
