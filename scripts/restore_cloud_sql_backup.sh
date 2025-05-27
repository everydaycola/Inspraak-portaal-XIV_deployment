#!/bin/bash

source modules/colors.sh
source modules/config.sh

INSTANCE_NAME="$DB_INSTANCE_NAME"
NEW_INSTANCE_NAME="${INSTANCE_NAME}-restored-$(date +%Y%m%d-%H%M%S)"

echo_in_green "Beschikbare backups voor isntance $INSTANCE_NAME"
backup_output=$(gcloud sql backups list -i "$INSTANCE_NAME" --format="value(ID)")
IFS=$'\n' read -r -d '' -a backups_array <<<"$backup_output"

# Verwijder eventuele lege elementen in de array
backups_array=("${backups_array[@]}")

if [ ${#backups_array[@]} -eq 0 ]; then
    echo_in_yellow "Er zijn geen backups gevonden voor instance '$INSTANCE_NAME'."
    exit 0
fi

# Toon de beschikbare backups met een nummer
echo_in_green "Selecteer een backup om te herstellen:"
for i in "${!backups_array[@]}"; do
    echo_in_green "$((i + 1))) ${backups_array[$i]}"
done

echo ""
read -p "Voer het nummer van de backup in die je wilt herstellen (of 'q' om te stoppen): " selected_number

if [ "$selected_number" == "q" ]; then
    echo_in_yellow "Restauratie geannuleerd."
    exit 0
fi

# Controleer of de input een geldig nummer is
if ! [[ "$selected_number" =~ ^[0-9]+$ ]]; then
    echo_in_red "Fout: Ongeldige input. Voer een nummer in."
    exit 1
fi

selected_index=$((selected_number - 1))

# Controleer of het geselecteerde nummer binnen het bereik ligt
if [ "$selected_index" -lt 0 ] || [ "$selected_index" -ge "${#backups_array[@]}" ]; then
    echo_in_red "Fout: Ongeldige selectie. Voer een nummer uit de lijst in."
    exit 1
fi

BACKUP_ID="${backups_array[$selected_index]}"

echo_in_yellow "WAARSCHUWING: Je staat op het punt de bestaande Cloud SQL instance '$INSTANCE_NAME' te herstellen naar backup '$BACKUP_ID'."
echo_in_yellow "ALLE HUIDIGE DATA OP DEZE INSTANCE DIE NIET IN DE BACKUP ZIT, ZAL VERLOREN GAAN."

read -p "Weet je zeker dat je wilt doorgaan? (ja/nee): " confirm

if [ "$confirm" != "ja" ]; then
    echo_in_yellow "Restauratie naar de bestaande instance geannuleerd."
    exit 0
fi

echo_in_green "Bezig met het herstellen van backup '$BACKUP_ID' naar de bestaande instance '$INSTANCE_NAME'..."

gcloud sql backups restore "$BACKUP_ID" \
    --restore-instance="$INSTANCE_NAME" \
    --backup-instance="$INSTANCE_NAME"

if [ $? -eq 0 ]; then
    echo_in_green "Backup '$BACKUP_ID' succesvol gerestaureerd naar de bestaande instance '$INSTANCE_NAME'."
    echo_in_yellow "De bestaande instance bevat nu de data van de backup."
else
    echo_in_red "Fout tijdens het restoren van de backup '$BACKUP_ID' naar de bestaande instance '$INSTANCE_NAME'."
fi
