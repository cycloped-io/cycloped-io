#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

%%{
  machine wikiparser;

  action text_position { text_start_position = (long)(p - start) + 1; }
  action store_text { text_end_position = (long)(p - start) - 6; 
    // print offset and text length
    printf("%li,%li\n",text_start_position,text_end_position-text_start_position); 
    id_seen = 0;
    count += 1;
    if(count % 1000 == 0){
      fprintf(stderr,"%li\n",count);
    }
  }
  action print_c { if(!id_seen){printf("%c",*p);} }
  action print_comma { if(!id_seen){printf(",");} id_seen = 1; }

  text_start =  /<text[^>]*>/;
  text_end   = '</text>';
  id_start =  /<id[^>]*>/;
#  id_start =  '<id>';
  id_end   = '</id>';

  main :=  ( id_start (digit @print_c) + id_end @print_comma | 
    text_start @text_position | text_end @store_text | any) * ;
}%%

%% write data;

int main( int argc, char **argv )
{
  int cs, res = 0;
  long id_start_position, id_len, text_start_position, text_end_position, count = 0;
  int page_size = sysconf(_SC_PAGE_SIZE);
  int file;
  char * p;
  struct stat file_info;
  long file_size,pages_count;
  int id_seen = 0;
  if ( argc == 2 ) {
    char *file_name = argv[1];
    file = open(file_name,O_RDONLY);
    if(file == -1){
      printf("File error %i\n",file);
      return file;
    }
    fstat(file,&file_info);
    file_size = file_info.st_size;
    pages_count = file_size / page_size + (file_size % page_size == 0 ? 0 : 1);
    p = (char*)mmap(NULL,pages_count * page_size,PROT_READ,MAP_SHARED,file,0);
    if(p == MAP_FAILED){
      printf("Mapping failed\n");
      return -1;
    }
    char *start = p;
    char *pe = p + file_size + 1;
    %% write init;
    %% write exec;
    munmap(p,pages_count * page_size);
    close(file);
  } else {
    printf("content_offset file.xml\n");
  }
  return 0;
}
