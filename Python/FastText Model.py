#!/usr/bin/env python
# coding: utf-8

# # Feed_Memo vs Feed_Description 
# 
# Links: 
# 
# [Spreadsheet](https://docs.google.com/spreadsheets/d/1NGT5TnvYf7vEY_q2piHuFtxDS_DDiLAZOp4wjqaD0E0/edit#gid=47721200)
# 
# [Gitlab Issue](https://gitlab.mx.com/mx/data-science/data-science-issues/-/issues/51)
# 
# [Helpful FastText documentation](https://towardsdatascience.com/fasttext-for-text-classification-a4b38cbff27c)
# 
# ###### Goal: create simple classification model that can predict if *feed_memo* or *feed_description* is a better choice for cleansing and categorizing incoming transactions.
# 
# Current state: 
# - I've collected as many submitted samples and gitlab issues related to this problem as I can find into the spreadsheet.  
# - I had a meeting with Matt Sharp to go over the [FastText model](https://fasttext.cc/) model and how it could be a good model for this problem. 
# - I am researching FastText as it has been used in previous MX models like Atlantis and QuickVerse.
# - I will create a test model with a small dataset to make sure that my model works as expected. 
# - Once my test model functions as expected, I will get the model into an [MLFlow](https://gitlab.mx.com/mlflow) project so that it can be reviewed, approved, and put into practice. 

# ### Current state
# 
# - I've collected as many submitted samples and gitlab issues related to this problem as I can find into the [Spreadsheet](https://docs.google.com/spreadsheets/d/1NGT5TnvYf7vEY_q2piHuFtxDS_DDiLAZOp4wjqaD0E0/edit#gid=47721200).  
# - I had a meeting with Matt Sharp to go over the [FastText model](https://fasttext.cc/) model and how it could be a good model for this problem. 
# - I have researched FastText as it has been used in previous MX models like Atlantis and QuickVerse.
# - I have created a test model with a small dataset to make sure that my model works as expected. 
# - Once my test model functions as expected, I will get the model into an [MLFlow](https://gitlab.mx.com/mlflow) project so that it can be reviewed, approved, and put into practice. 

# ### FastText and MX
# 
# MX engineering is done primarily in Ruby, which is a problem since it isn't a popular language for machine learning.  MX has used FastText in several projects since the model can be written with Python as the interface and then it is run in a Ruby machine. 
# 
# FastText is a slightly older (~5 years) NLP model.  It's a simple and efficient text classification algorithm that excels at doing simple, yes/no binary analysis.  It is a transformer and an encoder with a two layer neural network. 
# 
# ##### How FastText Works
# 
# The input for the model is a string. The model determines how to break up the words within that string (perhaps by spaces, a specific character, a *label*, etc). This is called tokenization.  The model builds a dictionary based off the words you feed it as you train it. As the model trains, it will start to recognize patterns based off how the words are split up. In a case like this project, we will add a label to the `feed_description` and `feed_memo` so that the model can recognize the label in each row as it trains. 
# 
# 
# ##### FastText and this Project
# 
# 1. We will swap half of the feed_memos and feed_descriptions so that the model will have half of the rows be non-swapped and half of the rows be swapped for training purposes.
# 
# 2. We will add a label to the `feed_description` and `feed_memo` columns for the model to recognize in each row. FastText expects labels to look like this:
# 
#     - `__labelname__`
#     
# 3. We will combine the `feed_description` and `feed_memo` columns into a single column (since FastText takes in a single string as the input). The pattern of each row should look like the below:
# 
#     - non-swapped order: `__feeddescription__ *feed_description here* __feedmemo__ *feed_memo here*`
#     - swapped order: `__feeddescription__ *feed_memo here* __feedmemo__ *feed_description here*`
#     
# 4. We will add in a label column that indicates if the row is swapped (1) or non-swapped (0)
#     
# 5. As the model trains, it will start to recognize the patterns and apply a binary output to each row based on if the model can predict if the transaction is in the non-swapped (0) or swapped (1) order. 
# 
# 6. Once we are sure the model is working as expected, we can put it into practice.  If the model labels a row as having the swapped (1) order, it will set a flag off so that MX's system will know that that transaction needs to go outside of Sherlock to be cleansed correctly. 
# 
# ![Dog%20is%20brown.png](attachment:Dog%20is%20brown.png)

# ### MLFlow
# 
# [MLFlow](https://gitlab.mx.com/mlflow) is the Gitlab that contains machine learning projects and experiments.  Since any projects will need to interact with MX's data and storage systems, there is a template for how projects need to be set up. The templates will need to be adjusted according to your specific project's needs. Using Jane's Atlantis model as an example, let's walk through how projects in MLFlow work:
# 
# #### [preprocess file](https://gitlab.mx.com/mlflow/atlantis/-/blob/master/preprocess.py)
# 
# - the first chunk of text is the template that allows your code to interact with MX's systems.
# - the first section you'll have to update is the SQL queries that ceph will use to pull data for the model.
# - once the data is pulled, you can preprocess the data:
#     - build the dataframe
#     - format the dataframe for fasttext
# - once the data is processed, you can split it into test and train sets.
# - finally, save the test and train sets as text files which are saved to ceph so that the data can be pulled from another file in the project.
# 
# #### [train file](https://gitlab.mx.com/mlflow/atlantis/-/blob/master/train.py)
# 
# - the first chunk of text is the template that allows your code to interact with MX's systems and throws errors if anything is wrong, like being unable to access to train and test files you previously saved to ceph.
# - after the file is successfully accessed, you create the model and train it using the train set. 
# - you'll be able to view results and statistics of this training at this point.
# 
# #### [training/extras file](https://gitlab.mx.com/mlflow/atlantis/-/tree/master/training)
# 
# - jane used additional resources (like Snorkel) to create her model, so she has additional files located here related to that.
# - this file also contains a process by which the data transactions were assigned a 0, 1, or 2 label. 

# ### STEP 0: Get the data

# Get a randomized dataset of 1,000,000 rows to train and test the model.
# 
# ```
# WITH trxs AS (
# 	SELECT feed_description, feed_memo, description, transaction_type, category_id, system_transaction_rule_guid FROM transactions
# 	WHERE date_id > 20210101
# 	AND feed_memo IS NOT NULL
# 	AND feed_description IS NOT NULL
# 	LIMIT 1000000
# )
# SELECT trxs.feed_description, trxs.feed_memo, trxs.description, trxs.transaction_type, categories.name, trxs.system_transaction_rule_guid FROM trxs
# LEFT JOIN categories on trxs.category_id = categories.id 
# ORDER BY random();
# ```

# ### STEP 1: Prep

# In[33]:


# import libraries
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
import fasttext
get_ipython().run_line_magic('matplotlib', 'inline')

print("libraries imported")


# In[3]:


# pip install pip --upgrade


# In[4]:


# pip install notebook --upgrade


# In[45]:


# store the data
fasttext_df = pd.read_csv("FastText_data.csv")
fasttext_df.head()


# In[46]:


# dataset shape
fasttext_df.shape


# In[47]:


# check how many transactions are cleansed by transaction rules
fasttext_df["system_transaction_rule_guid"].value_counts()


# In[48]:


# how many transactions aren't cleansed by sherlock stack:
fasttext_df['system_transaction_rule_guid'].isna().sum()
# 136147/1000000 = 13.6%


# In[49]:


# drop unneeded columns
fasttext_df = fasttext_df.drop(['description', 'transaction_type', "name", "system_transaction_rule_guid"], axis=1)


# ### STEP 2: Swap half of the feed_memo and feed_description columns

# In[50]:


fasttext_df.head(10)


# In[51]:


# swap fasttext dataset
mask = fasttext_df.index % 2 == 1

fasttext_df.loc[mask, ['feed_description', 'feed_memo']] = fasttext_df.loc[mask, ['feed_memo', 'feed_description']].to_numpy()


# In[52]:


# view swapped dataset
fasttext_df.head(10)


# ### STEP 3: combine feed_description and feed_memo columns

# In[53]:


# now combine columns in fasttext dataset

fasttext_df["combined"] = fasttext_df["feed_description"] + fasttext_df["feed_memo"]


# In[54]:


fasttext_df.head()


# ### STEP 4: add label column

# In[55]:


# add label column
# 1 = swapped
# 0 = non-swapped

fasttext_df["swapped_label"] = np.where(mask, '1', '0')


# In[56]:


# drop unneeded feed_description, feed_memo columns

fasttext_df = fasttext_df.drop(["feed_description", "feed_memo"], axis=1)


# In[67]:


fasttext_df.head()


# ### STEP 5: Pre-Process the data

# In[68]:


# preprocess data in the format that fasttext wants it
processed_data = '__label__'+fasttext_df['swapped_label'].apply(str)+' '+fasttext_df['combined']


# ### STEP 6: Create train and test sets

# In[69]:


# get training and testing sets
train, test = train_test_split(processed_data)


# In[70]:


# check the data
train.head()


# In[71]:


processed_data.sample(5)


# ### STEP 7: Save the text files

# In[62]:


# save as text files
train.to_csv("train.txt", index=False, header=False)
test.to_csv("test.txt", index=False, header=False)


# ### STEP 8: Train the model

# In[63]:


# create and train the model
model = fasttext.train_supervised("train.txt")


# ### STEP 9: Evaluate performance

# In[77]:


# evaluate performance on the entire test file
model.test("test.txt")

# number of samples in test dataset: 241,034
# precision: .8007
# recall: .8007


# `Precision`: the number of number of correctly predicted labels over the number of total labels predicted by the model. 
# 
# `Recall`: the number of correctly predicted labels over the number of actual lables from the validation dataset.

# In[81]:


# predict on a single input
model.predict(test.iloc[100])

# the model predicted label_0 (not swapped) with probability 95.8%


# In[80]:


test.iloc[100]


# ### STEP 10: Save the model

# In[82]:


model.save_model("model.bin")

