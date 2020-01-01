# Custom `select` implementation that allows *empty* input.
# Pass the choices as individual arguments.
# Output is the chosen item, or "", if the user just pressed ENTER.
# Example:
#    choice=$(select_with_default 'one' 'two' 'three')
select_with_default() {

  local item i=0 numItems=$# 

  # Print numbered menu items, based on the arguments passed.
  for item; do         # Short for: for item in "$@"; do
    printf '%s\n' "$((++i))) $item"
  done >&2 # Print to stderr, as `select` does.

  # Prompt the user for the index of the desired item.
  while :; do
    printf %s "${PS3-#? }" >&2 # Print the prompt string to stderr, as `select` does.
    read -r index
    # Make sure that the input is either empty or that a valid index was entered.
    [[ -z $index ]] && break  # empty input
    (( index >= 1 && index <= numItems )) 2>/dev/null || { echo "Invalid selection. Please try again." >&2; continue; }
    break
  done

  # Output the selected item, if any.
  [[ -n $index ]] && printf %s "${@: index:1}"

}

echoerr () {
    printf '%s\n' "$1" >&2
}

prompt_for_value() {
    # $1 = value of existing env var to check
    # $2 = Human name of field to input
    # $3 = Prompt message
    # $4 = optional Extra help instructions
    # $5 = optional default answer
    if [ "$1" == "" ]; then
        echoerr "-----------------------------------------------------------------------------"
        echoerr " *****   $2   *****  $4"
        echoerr "-----------------------------------------------------------------------------"
        while [ -z "$READ_RESPONSE" ]; do
            echoerr "$3"
            read -r READ_RESPONSE
            READ_RESPONSE="${READ_RESPONSE:-$5}"
        done
        echo "$READ_RESPONSE"
    else
        echoerr "Found $2 as environment variable so moving on"
        echo "$1"
    fi
}
