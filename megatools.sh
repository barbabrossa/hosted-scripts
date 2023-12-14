#!/bin/bash
# https://docs.ultra.cc/books/megatools/page/setting-up-megatools

set -euo pipefail

cd "${HOME}" || exit

printf "\033[0;31mDisclaimer: This installer is unofficial.\033[0m\n"
read -rp "Type confirm word if you wish to continue: " input
if [ ! "$input" == "confirm" ]
then
    exit 0
fi
echo

grab_latest_version() {
    LATEST=$(curl -s https://megatools.megous.com/builds/LATEST)
    mkdir -p "$HOME"/mega
    mkdir -p "$HOME"/.megatools-tmp
    cd "$HOME"/.megatools-tmp || exit
    wget -qO megatools.tar.gz "https://megatools.megous.com/builds/builds/${LATEST}-linux-x86_64.tar.gz"
    tar -xf megatools.tar.gz "${LATEST}-linux-x86_64/megatools" && mv "${LATEST}-linux-x86_64/megatools" "${HOME}/mega/"
    rm -rf "$HOME"/.megatools-tmp
}

old_install(){
    if [ -f "${HOME}/mega/megadl" ] || [ -f "${HOME}/mega/megatools" ]; then
        return 0
    fi

    return 1
}

uninstall() {
    rm -rf "$HOME"/mega/{megacopy,megadf,megadl,megaget,megals,megamkdir,megaput,megareg,megarm}
    rm -rf "${HOME}/mega/megatools"
}

if ! old_install; then
    grab_latest_version
    echo "$LATEST installed successfully."
    echo
    exit 0
fi

echo "Old megatools installation detected."
echo "How do you wish to proceed?"
select status in 'Update' 'Uninstall' 'Quit'; do
    case ${status} in
    'Update')
        uninstall
        grab_latest_version
        echo
        echo "megatools updated."
        echo
        exit 0
        break
        ;;
    'Uninstall')
        uninstall
        echo
        echo "megatools uninstalled."
        echo
        exit 0
        break
        ;;
    'Quit')
        exit 0
        ;;
    *)
        echo "Invalid option $REPLY. Choose between 1-3."
        ;;
    esac
done

exit 0
