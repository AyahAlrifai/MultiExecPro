## How to use it?
1. put this file in the folder where all microservices or folders that you want to make the same action on it.
2. Open Powershell then run this command.
```
./all.psa
```
3. We will show the command screen, you can insert multiple commands separated by `&&` and we will execute them in the same order for each microservice.
4. You can use `up/down` arrows to move between previous commands.
5. click `enter` to start the process.
6. We will show all microservices folders.
7. Use `up/down` arrows to move between microservices.
8. Click on the `space` to select or deselect the microservice.
9. Click on the `enter` to execute.
10. We will run commands in the same order and run on microservices in the same order you select them.
```
if you insert these commands git status && git pull, and select these microservices tpp-microservice and workflow-microservice
we will run them in this order:
tpp-microservice -> git status
tpp-microservice -> git pull
workflow-microservice -> git status
workflow-microservice -> git pull
```
11. After finishing click on the `enter` to return to the command screen or insert `n` or `N` then click on the `enter` to exit
12. You can cancel the process at any time by clicking on Ctrl+C
