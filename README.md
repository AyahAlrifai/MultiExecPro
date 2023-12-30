## How to use it?
1.Download file `all.ps1`.
2. put this file in the folder where all microservices or folders that you want to make the same action on it.
3. Open Powershell then run this command.
  ```
  ./all.psa
  ```
4. We will show the command screen, you can insert multiple commands separated by `&&` and we will execute them in the same order for each microservice.
5. You can use `up/down` arrows to move between previous commands.
6. click `enter` to start the process.
7. We will show all microservices folders.
8. Use `up/down` arrows to move between microservices.
9. Click on the `space` to select or deselect the microservice.
10. Click on the `enter` to execute.
11. We will run commands in the same order and run on microservices in the same order you select them.
  ```
  if you insert these commands git status && git pull, and select these microservices tpp-microservice and workflow-microservice
  we will run them in this order:
  tpp-microservice -> git status
  tpp-microservice -> git pull
  workflow-microservice -> git status
  workflow-microservice -> git pull
  ```
12. After finishing click on the `enter` to return to the command screen or insert `n` or `N` then click on the `enter` to exit
13. You can cancel the process at any time by clicking on Ctrl+C

---

Regards @AyahAlrifai

Experienced Software Developer with a demonstrated history of working in the Student information system and Child protection system. 
Skilled in java, Mysql Database, and OOP. Information technology professional with a Bachelor's degree in Computer Engineering from 
Jordan University of Science and Technology.

I am highly organized, I can learn any new technology, work in a team or independently, and work under deadline pressure in a fast-paced 
environment footsteps, I have a -high ability to solve problems, and good communication and interpersonal skills.

 📫 How to reach me alrefayayah@gmail.com
