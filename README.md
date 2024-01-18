[About Ayah Alrefai](https://github.com/AyahAlrifai/AyahAlrifai/blob/main/README.md)

# Multi Execute Pro

## How to use it?

- Download file `multiExecPro.ps1`.
- put this file in the folder where all microservices or folders that you want to make the same action on it.
- Open Powershell then run this command one time.
  ```
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```
- go to `multiExecPro.ps1` location then on powershell run this command.
  ```
    ./multiExecPro.ps1
  ```
- We will show the command screen, you can insert multiple commands separated by `&&` and we will execute them in the same order for each microservice.
- You can use `up/down` arrows to move between previous commands.
- click `enter` to start the process.
- We will show all microservices folders.
- Use `up/down` arrows to move between microservices.
- Click on the `space` to select or deselect the microservice.
- Click on the `enter` to execute.
- We will run commands in the same order and run on microservices in the same order you select them.
  ```
  if you insert these commands git status && git pull, and select these microservices tpp-microservice and workflow-microservice
  we will run them in this order:
  tpp-microservice -> git status
  tpp-microservice -> git pull
  workflow-microservice -> git status
  workflow-microservice -> git pull
  ```
- After finishing click on the `enter` to return to the command screen or insert `n` or `N` then click on the `enter` to exit
- You can cancel the process at any time by clicking on Ctrl+C
