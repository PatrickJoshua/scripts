if ioreg -n Root -d1 | grep -q "CGSSessionScreenIsLocked"; then
    echo "The Mac is LOCKED."
else
    echo "The Mac is UNLOCKED."
fi
