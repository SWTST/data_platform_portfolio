```
title: "Lists"
date: 2025-09-24
course: Codeacademy > Learn Python 3
tags: [#python-basics, #python-syntax]
summary: Python - Lists
```

# Lists

## 1 Dimensional Lists
Lists are a way to store multiple data values within the same variable. These values do not need to be off the same data types and follow the basic syntax below:
```
my_list = [value1, value2, ...]
```

Lists are zero-indexed and you can select specific elements from lists using this syntax:
```
#Positive Indexing
my_list[0]

#Negative Indexing
my_list[-1]
```
You can also use **methods()**, which are like built-in functions, to carry out various actions on the lists. e.g. add or remove, and some of these are below:
```
my_list.append[value1, value2, ...]
my_list.remove[value1, value2, ...]
```

Lists can also be concatenated to form joined, new lists with the below syntax:
```
my_list = [value1, value2, ...]
my_other_list = [value1, value2, ...]

new_list = my_list + [value1, value2, ...]
# OR
new_list = my_other_list + my_list
```

## 2 Dimensional Lists
Lists can also be stored within other lists to contain more than one data value within each original list's elements. This can be useful for storing related data, for example: Student names and student test scores. The basic syntax is below:
```
my_2d_list = [
    [value1, value1.1],
    [value2, value2.1],
    [value3, value3.1],
    ...]
```

These lists can be indexed similarly to single dimension lists but need 2 positional arguments, as follows:
```
my_2d_list[1][0]
#OR
my_2d_list[-1][-1]
```