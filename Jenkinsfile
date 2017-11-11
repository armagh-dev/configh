#!groovy

import hudson.Util;

def sendToSlack() {

  def buildDuration = Util.getTimeSpanString(System.currentTimeMillis() - currentBuild.startTimeInMillis)
  def color = 'good'

  if(currentBuild.result != "SUCCESS") {
    color = 'danger'
  }

  slackSend color: color, message: "${env.JOB_NAME} - #${env.BUILD_NUMBER} ${currentBuild.result} after ${buildDuration} (<${env.BUILD_URL}|Open>)"

}

def isNewBuild(name) {
  def current_version = sh(script: 'rake version', returnStdout: true).trim()
  def result = sh(script: "gem search ^${name}\$", returnStdout: true).trim()
  def latest_version = (result =~ /\((.+)\)/)[0][1]
  return current_version != latest_version
}

try {

currentBuild.result = "Success"


  node('armagh-builder') {

     stage('Prep') {

       deleteDir()
     
       checkout scm

       sh """#!/bin/bash -l
         echo -e "*********************************************\n** Preparing:" `hg identify -i` "\n*********************************************"
         set -e
         gem install bundler --no-doc
         bundle install
         ruby --version
         mongod --version
       """
     }
  
     stage('Unit Test') {
     
       sh """#!/bin/bash -l
         echo -e "*********************************************\n** Unit testing:" `hg identify -i` "\n*********************************************"
         set -e
         bundle exec rake test
       """
     }
  
     stage('Integration Test') {
     
       sh """#!/bin/bash -l
         echo -e "*********************************************\n** Integration testing:" `hg identify -i` "\n*********************************************"
         set -e
         bundle exec rake integration
       """
     }

     stage('Rcov') {
     
       publishHTML (target: [
         allowMissing: false,
         alwaysLinkToLastBuild: false,
         keepAll: true,
         reportDir: 'coverage/rcov',
         reportFiles: 'index.html',
         reportName: "RCov Report"
       ])
     }

     stage('Yard') {

       sh """#!/bin/bash -l
         echo -e "*********************************************\n** Yard:" `hg identify -i` "\n*********************************************"
         set -e
         bundle exec rake yard
       """
     
       publishHTML (target: [
         allowMissing: false,
         alwaysLinkToLastBuild: false,
         keepAll: true,
         reportDir: 'doc',
         reportFiles: 'index.html',
         reportName: "YARD Documentation"
       ])
     }

     stage('Prerelease') {
       if ((env.BRANCH_NAME == "default") && (currentBuild.result == 'SUCCESS') && isNewBuild('configh')) {

         sh """#!/bin/bash -l
           echo -e "*********************************************\n** Prereleasing:" `hg identify -i` "\n*********************************************"
           set -e
           bundle exec rake prerelease
         """

         build job: '/armagh-base-actions/default', wait: false
       }
     }
  }
}

catch( err ) {
  currentBuild.result = "FAILURE! - ${err}"
  throw err
}

finally {

  println "********************\n** EXECUTING FINALLY BLOCK \n********************\n"

  sendToSlack()

  // Remove older build
  properties([[$class: 'BuildDiscarderProperty', strategy: [$class: 'LogRotator', artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '10']]]);

}
