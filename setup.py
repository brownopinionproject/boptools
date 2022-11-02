from setuptools import setup

setup(name='boptools',
      version='0.12',
      description='Brown Opinion Project utilities.',
      url='https://github.com/brownopinionproject/boptools/tree/main',
      author='Arjun Shanmugam',
      author_email='arjun_shanmugam@brown.edu',
      license='MIT',
      packages=['boptools'],
      install_requires=[
            'pandas',
            'numpy',
            'matplotlib',
            'weightedcalcs'
      ],
      tests_require=['pytest'],
      zip_safe=False)