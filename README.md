![CoG](https://raw.githubusercontent.com/CentauriSoldier/CoG/main/logo.png)

 Code of Gaming - A lua framework containing support scripts such as shapes, abstract potentiometers, value modifier classes and more.

## Version

Changelog

**0.5**
- Change: updated all modules and classes to use the new LuaEx system.
- Change: removed queue class.
- Change: removed stack class.

**0.4**
- Removed the class module (as well other commonly-used Lua libraries) and ported them to a new project. Added CoG's dependency on said project.

**0.3**
- Created an init module to allow for a single require call to CoG which loads all desired modules.

**0.2**
- Added the class module (create by Bas Groothedde).
- Added several classes.</p>

**0.1**
- Compiled various modules into CoG.

# Work in Progress
This project is in alpha so some of the code will not yet work. I will delete this message once the project is in beta and ready for use.

# Required Modules
While the classes (listed below) are optional to your project, some depend on the scripts listed in this section and, as such, will not function without these being required.

## Require Order
* class
* const
* math


# The Classes (optional)

## iota
This class is, in effect, a clock/calendar system. It requires the client to update it at the desired intervals but handles all the math and logic of the clock system whenever a change is made to any of the types (seconds, minutes, hours, etc.).

### Planned Features
Add Day Names, Weeks, Months and Days in Each Month

## point
This is a very simple point class that has no private fields or methods.

#### Fields
* x *A numeric value representing the x value of the point.*
* y *A numeric value representing the y value of the point.*

#### Methods
