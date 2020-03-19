mkdir leroi
cd leroi
virtualenv env --python=python3
source env/bin/activate

wget https://openei.org/doe-opendata/dataset/9dcd443b-c0e5-4d4a-b764-5a8ff0c2c92b/resource/4e994236-813f-436f-8e8c-fb38543ba432/download/tractnc2015.csv

jupyter notebook
or
jupyter notebook --ip=$IP --port=$PORT --no-browser

