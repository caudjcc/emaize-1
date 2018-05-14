#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>
using namespace std;

const size_t buffer_size = 1024*1024*16;

void genotype_to_corpus()
{
    char* line = new char[buffer_size];
    char* buffer = new char[buffer_size];

    setbuffer(stdout, buffer, buffer_size);

    int iline = 0;
    vector<char> genotypes;
    vector<const char*> cols;
    while(!feof(stdin))
    {
        if(fgets(line, buffer_size, stdin) == NULL)
            break;
        // determine the number of columns

        const char* col = strtok(line, "\t");
        int icol = 0;
        while(col != NULL)
        {
            if(iline == 0)
                cols.push_back(col);
            else
                cols[icol] = col;
            col = strtok(NULL, "\t");
            icol ++;
        }
        if(iline == 0)
            genotypes.resize(cols.size() - 4);
        if((iline != 0) && (strcmp(cols[0], "snp")))
        {
            const char* alleles = cols[1];
            for(int allelle = 0; allelle < 3; allelle ++)
            {
                genotypes.assign(genotypes.size(), 0);
                for(size_t i = 4; i < cols.size(); i ++)
                {
                    int sample_id = i - 4;
                    col = cols[i];
                    // AA -> 100
                    // AB -> 010
                    // BB -> 001
                    if((allelle == 0) && (col[0] == alleles[0]) && (col[1] == alleles[0]))
                        genotypes[sample_id] = 1;
                    else if((allelle == 1) && ((col[0] == alleles[0]) && (col[1] == alleles[2]))
                      ||(col[0] == alleles[2]) && (col[1] == alleles[0]))
                        genotypes[sample_id] = 1;
                    else if((allelle == 2) && (col[0] == alleles[2]) && (col[1] == alleles[2]))
                        genotypes[sample_id] = 1;
                }
                fwrite(reinterpret_cast<const char*>(&genotypes[0]), 1, genotypes.size(), stdout);
            }
        }
        iline ++;
    }
}

int main(int argc, char** argv)
{
    genotype_to_corpus();

    return 0;
}
