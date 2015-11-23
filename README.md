# Code in the Dark Editor
![image](https://cloud.githubusercontent.com/assets/688415/11338071/19167072-91f2-11e5-9eb6-3e6799fa60aa.png)

## How to Use
* Grab the contents of the [`dist/`](https://github.com/codeinthedark/editor/tree/master/dist) folder. All contestants should be given a copy of the editor.
* Replace `assets/page.png` in the editor files with a screenshot of the page that is to be built in the competition. 
* Add any extra assets (e.g. images) that are required to build the page in the `assets/` folder.
* Edit the `assets/instructions.html` file with information about the extra assets and their dimensions.

## Developing
Here's how to install the dependencies and run the editor locally:
```bash
$ npm install
$ ./node_modules/.bin/gulp serve
```

To build the editor, run:
```bash
$ gulp build
```
This will compile all scripts and styles and inline them into a single html file in the `dist/` folder. It will also create a `dist/assets/` folder, which separately contains the instructions and page screenshot so that they can easily be changed between different rounds of the competition. 

## Contributing
Contributions to the editor welcome. If you've fixed a bug or implemented a cool new feature that you would like to share, please feel free to open a pull request here. 
