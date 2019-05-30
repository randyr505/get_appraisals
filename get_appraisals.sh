#!/bin/sh
. ./get_appraisals.cfg

# counter for output only
count=1
# regex for digit
re='^[0-9]+$'

check_file() {
  [ -f $1 ] || return 1
}

validate_pdf() {
  check_file $1 && file $1 | grep 'PDF document' >/dev/null || return 1
}


printf  "%-15s %-20s %-20s %-20s %-13s %-10s %s\n" 'Property Id' 'Previous Appraisal' 'Proposed Appraisal' 'Current Appraisal' 'Square Feet' 'Cost/sf' 'Address' | tee -a $results

for property_id in $(awk '{print$1}' $input | egrep -v '([a-z]|[A-Z]|#)')
do
  echo "Fetching value number $count ($property_id)"

  # Prevent site from blocking you by mimicing an actual browser
  check_file $data/${property_id}.html || \
    { sleep 1; wget --quiet --header="$user_agent_header" --header="$language_header" --header="$referer_header" \
      --header="Accept: text/html" "${property_url}${property_id}&year=$year" -O $data/${property_id}.html; }

  check_file $data/${property_id}.pdf || \
    { sleep 1; wget --quiet --header="$user_agent_header" --header="$language_header" --header="$referer_header" \
      --header="Accept: text/html" "${property_notice}/${property_id}.pdf" -O $data/${property_id}.pdf; }

    values="0"
    validate_pdf $data/${property_id}.pdf && values=$(pdfgrep 'Appraised Value' $data/${property_id}.pdf | awk '{a=NF-1; print$NF" "$a}')
    previous_appraisal="$(echo $values | awk '{print$2}' | sed '/,/s///g')"
    
    proposed_appraisal="$(echo $values | awk '{print$1}' | sed '/,/s///g')"
    [[ $previous_appraisal =~ $re ]] || previous_appraisal="0"
    [[ $proposed_appraisal =~ $re ]] || proposed_appraisal="0"

  square_feet=$(egrep 'Total Main Area|Total Improvement Main Area' $data/${property_id}.html | awk -F\> '{print$4}' | awk '{print$1}' | sed '/,/s///g')
  square_feet=$(echo $square_feet | awk '{print$1}')

  check_file $input && current_appraisal="$(grep $property_id $input | awk '{a=NF-2; print $a}')"
  if  ! [[ $current_appraisal =~ $re ]];
  then
    current_appraisal="0" 
    costsf=$(echo "scale=2; $proposed_appraisal/$square_feet" | bc -l) || costsf="N/A"
  else
    current_appraisal_fmtd=$(echo $current_appraisal | sed -e '/,/s///g' -e '/\$/s///g')
    costsf=$(echo "scale=2; $current_appraisal_fmtd/$square_feet" | bc -l)
  fi

  check_file $data/${property_id}.html && address=$(grep "Property Address" $data/${property_id}.html | awk -F\> '{print$4}' | awk -F\< '{print$1}') || address="N/A"

  printf "%-15d %-20s %-20s %-20s %-13s %-10s %-60s\n" $property_id $previous_appraisal $proposed_appraisal $current_appraisal $square_feet $costsf "$address" | tee -a $results
  
  let count=$count+1
done
