import pandas as pd
import numpy as np

links_summary = pd.ExcelFile('data/links summary 1118.xlsx')
linkssum = links_summary.parse(0)

ls = linkssum.drop(columns=['WATER_SUPPLIER_NAME', 'old code', 'WATER_SUPPLY',
                           'ADDITIONAL_WATER_SUPPLY_DETAIL', 'Purchased_WATER_QUALITY',
                           'Final_WATER_QUALITY', 'Unnamed: 30', 'Unnamed: 31', 'Unnamed: 32',
                            'WATER_SUPPLIER_NAME.1']) #drop columns that aren't used in final links table

#rename columns that had case mismatch
ls = ls.rename(columns={'2015_Cum_Demand': '2015_Cum_demand', '2025_Cum_Demand': '2025_Cum_demand'})

#drop any empty rows
ls = ls[ls['Node5'] != 0]
ls = ls[ls['Node4'] != 0]

def get_rows(r, source_node, target_node):
    '''Function that computes rows for the final links table.
    It iterates through every fifth year from 2015 to 2040.
    
    Args:
        r (Pandas Series): row of the excel sheet
        source_node (str): column name for the source, e.g. "Node1"
        target_node (str): column name for the target
    
    Returns:
        list: the list of dictionaries that can be put into
        a Pandas DataFrame
    '''
    rows = []  # list to return
    
    for year in np.arange(2015, 2041, 5):  # iterate over each year
        row = {}  # row to construct for given year
        
        row['year'] = year       # year for both predicted and data
        row['data_year'] = 2015
        
        row['source'] = r[source_node]  # find source/target using
        row['target'] = r[target_node]  # function args
        
        node_num = target_node[4]  # get the target node number
        if node_num == '5':
            row['transmission_kwh/af'] = r['Trans_kWh/AF_Node4to5']    # get relevant information for end node
            row['cumulative_volume_af'] = r[str(year) + '_End_Demand']
            row['used_vol_af'] = r[str(year) + '_End_Demand']
        
        else:
            c_label = str(year) + '_Cum_demand'       # get info for the rest of the nodes
            row['cumulative_volume_af'] = r[c_label]  # "else" case does nodes 3 to 4.
            row['used_vol_af'] = 0
            
            if node_num == '2':
                row['transmission_kwh/af'] = r[5]     # r[#] is the column number for the
                row['treatment_kwh/af'] = r[6]        # node specfic trans/trt intensity

            elif node_num == '3':
                row['transmission_kwh/af'] = r[7]
                row['treatment_kwh/af'] = r[8]

            else:
                row['transmission_kwh/af'] = r[9]
                row['treatment_kwh/af'] = r[10]
        
        rows.append(row) # append final dict to list of rows
        
    return rows

# construct links table. the original set up was skipping through nodes 4 to 5, so 
# I deleted the control sequence. This might take longer but it's more comprehensive.
rows = []
for i, r in ls.iterrows():
    n1 = get_rows(r, 'Node1', 'Node2')    
    rows.extend(n1)
    n2 = get_rows(r, 'Node2', 'Node3')
    rows.extend(n2)
    n3 = get_rows(r, 'Node3', 'Node4')
    rows.extend(n3)
    n4 = get_rows(r, 'Node4', 'Node5')
    rows.extend(n4)

# get the columns from the 2010 links table; use this for ordering the columns
ol = pd.read_csv('data/links_erl.csv')

data = pd.DataFrame(rows)  # putting the data in the list into a dataframe
data = data[ol.columns]    # reorder the oclumns

# drop rows where both source and target are 0 in the table
ind = []
for i, v in data.iterrows():
    if v['source'] == 0 and v['target'] == 0:
        ind.append(i)

data = data.drop(ind).reset_index(drop=True)

# export data into csv
data.to_csv('data_cleaning/with_nans.csv', index=False)


#############################################################################
####                                                                     ####
####   BELOW IS THE CODE TO REMOVE REPEATS SPECIFIED IN (3) IN THE DOC   ####
####                                                                     ####
#############################################################################

# find all rows in which the source is not a string (i.e. it's blank or contains 0)
find = []
for i in data.index:
    if type(data.loc[i]['source']) != str:
        find.append(i)
        
# this cell takes the four columns and if NaN shows up in ANY of the four columns, then the cell is not
# in the final list. This list is used to find the source+target+energy repeats, but not different energy 
# intensity values (#3 on the doc).
consolidate = []

f = data[['source', 'target', 'transmission_kwh/af', 'treatment_kwh/af']]

f.replace(np.nan, False, inplace=True)  # replace the NaN values with False, which makes it easier
                                        # to sort when iterating through the table
for i, a, b, c, d in f.itertuples():
    quads = (a, b, c, d)
    if all(quads):  # if all values in tuple are true, then append the tuple to the list. else, skip over it.
        consolidate.append(quads)
    else:
        pass

consolidate = list(set(consolidate)) # puts it into a set, which removes all duplicates, and convert back to list.

# use list of quadruples found in last cell to get the summed volumes for cells, repeated or not. 
# if it isn't repeated, then the volumes are the same.
new_rows = []
for i in consolidate:
    source = i[0]  # first value in tuple was source, second was target, etc.
    target = i[1]
    trans = i[2]
    treat = i[3]
    
    duo = data[(data.source == source) & 
               (data.target == target) & 
               (data['transmission_kwh/af'] == trans) & # find rows in which all four columns  
               (data['treatment_kwh/af'] == treat)]     # match the four values in quadruple
    
    for year in np.arange(2015, 2041, 5):  # iterate through each year again
        new = {}

        new['year'] = year
        new['data_year'] = 2015
        new['source'] = source
        new['target'] = target
        
        # get the year and take the sum of the cumulative volumes; if one rows, volume value stays same.
        sub = duo[duo.year == year]       
        new['cumulative_volume_af'] = sum(sub['cumulative_volume_af'].values)
        
        # keep same trans/trt energy intensities
        new['transmission_kwh/af'] = trans
        new['treatment_kwh/af'] = treat
        
        # sum the used volume if we are dealing with an end node.
        new['used_vol_af'] = sum(sub['used_vol_af'])
        
        # append dictionary to new_rows for use in dataframe
        new_rows.append(new)

# put the cleaned repeats into a dataframe
consol1 = pd.DataFrame(new_rows)
consol1 = consol1[ol.columns]
consol1

# write to csv
consol1.to_csv('data_cleaning/no_nans.csv', index=False)