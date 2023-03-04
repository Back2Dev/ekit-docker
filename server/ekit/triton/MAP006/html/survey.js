function update_agreement() {
  if ($('post_agreement').checked == true)
    $('agreement_div').className='agreement_panel_hot'; 
  else
    $('agreement_div').className='agreement_panel_cold'; 
}