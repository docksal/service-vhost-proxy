/**
 * Inline Source can compress tags that contain the inline attribute
 * Supports <script>, <link>, and <img>
 */
const { inlineSource } = require('inline-source');

// Colored terminal output
const chalk = require('chalk');

const fs = require('fs');
const path = require('path');

// cd into the cirectory where build.js is
process.chdir(__dirname)

// Loading Page
const loadingPage = path.resolve('_loading_template.html');

inlineSource(loadingPage, { compress: true, }).then(html => {
  console.log(chalk.green('Writing loading.html...'));
  fs.writeFileSync('loading.html', html);
}).catch(err => {
  console.error(`Failed generating loading.html \n${err}`);
});

// Not Found Page
const notFoundPage = path.resolve('_not-found_template.html');

inlineSource(notFoundPage, { compress: true, }).then(html => {
  console.log(chalk.green('Writing not-found.html...'));
  fs.writeFileSync('not-found.html', html);
}).catch(err => {
  console.error(`Failed generating not-found.html \n${err}`);
});
