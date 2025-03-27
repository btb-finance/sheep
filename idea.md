How the Two-Dog Rotation System Works
Your solution uses two separate deposit addresses with the SheepDog contract, creating an alternating cycle:

Initial Setup:

Your contract creates two "positions" in the SheepDog (let's call them Dog A and Dog B)
Dog A is actively holding deposits
Dog B immediately goes into "sleep" mode (withdrawal process)


Steady State Operation:

New user deposits go into the active dog (Dog A)
Withdrawal requests are queued for processing
When Dog B's 2-day waiting period is over, your contract:

Withdraws funds from Dog B
Processes all queued withdrawal requests
Sends remaining funds back to SheepDog as Dog B (now active again)
Puts Dog A to sleep


The cycle continues with roles reversed


Continuous Availability:

Every ~2 days, a batch of funds becomes available for withdrawal
Users know when to expect their withdrawals
No risk of missing the 2-day claim window because the process is automated