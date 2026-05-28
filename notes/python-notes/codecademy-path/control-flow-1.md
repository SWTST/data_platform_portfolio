```
title: "Control Flow Session 1"
date: 2025-09-17
course: Codeacademy > Learn Python 3
tags: [#python-basics, #python-syntax]
summary: Python - Control Flow
```

# Control Flow

## Match-Case statements

Match - Case statements can be used as a replacement for if, elif, else statements and were introduced in Python 3.10. They provide a more lightweight way to write, if equals a value; execute the following. This syntax is below.

**The below is examples of an if/elif/else block**
```
user_name = "Dave"  
if user_name == "Dave":   
    print("Get off my computer Dave!")   
elif user_name == "angela_catlady_87":   
    print("I know it is you, Dave! Go away!")   
elif user_name == "Codecademy":   
    print("Access Granted.")   
else:   
    print("Username not recognized.") 
```
**The following can be used in its place as a more lightweight way to evaluate the same values**
```
user_name = "Dave"  
switch user_name:  
    case "Dave":  
        print("Get off my computer Dave!")  
    case "angela_catlady_87":  
        print("I know it is you, Dave! Go away!")   
    case "Codecademy":  
        print("Access Granted.")  
    case default:  
        print("Username not recognized.")  
```

**The general declaration and syntax is below**
```
match expression:  
    case value_1:  
        # code to execute when expression equals value_1  
    case value_2:  
        # code to execute when expression equals value_2  
    case value_3:  
        # code to execute when expression equals value_3  
    case value_4:  
        # code to execute when expression equals value_4  
    case value_N:  
        # code to execute when expression equals value_N  
    case default:  
        # code to execute when expression isn't equal to any of the values  
```

## Mini Project: Magic 8-Ball

Brief was given on CodeAcademy for a simple demonstration, there was optional tasks to add validation checks on variables but I did not add these in as we are hardcoding variables as oppose to getting the data elsewhere. The code is below: 
```
import random

name = "leah"
question = "Can I be Horizontal yet?"
answer = ""

rnumber = random.randint(1,9)

if (rnumber == 1):
  answer = "Yes - definetly"
elif (rnumber == 2):
  answer = "It is decidedly so"
elif (rnumber == 3):
  answer = "Without a doubt"
elif (rnumber ==4):
  answer = "Reply hazy, try again"
elif (rnumber == 5):
  answer = "Ask again later"
elif (rnumber == 6):
  answer = "Better not tell you now"
elif (rnumber == 7):
  answer = "My sources say no"
elif (rnumber == 8):
  answer = "Outlook not so good"
elif (rnumber == 9):
  answer = "Very doubtful"
else:
  answer = "Error"

print(name + " asks: " + question)
print("Magic 8-Ball's answer: " + answer)
```

## Introduction to Bugs

In python there are many different ways of classifying errors but some of the basic/most common are below:

- SyntaxError: Error caused by not following the correct Python language structure (syntax).
- NameError: Errors reported when the interpreter detects a variable that is unknown.
- TypeError: Errors thrown when operations are applied to an object of inappropriate type.
