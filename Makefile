NAME	= libasm.a

SRCS	= ft_strlen.s ft_strcpy.s ft_strcmp.s ft_write.s ft_read.s ft_strdup.s

BONUS	= ft_atoi_base.s ft_list_push_front.s ft_list_size.s ft_list_sort.s \
		  ft_list_remove_if.s ft_calloc.s ft_simd_memchr.s

OBJDIR	= obj
OBJS	= $(addprefix $(OBJDIR)/, $(SRCS:.s=.o))
BOBJS	= $(addprefix $(OBJDIR)/, $(BONUS:.s=.o))

NASM	= nasm
NFLAGS	= -f elf64
AR		= ar rcs

all: $(NAME)

$(NAME): $(OBJS)
	$(AR) $(NAME) $(OBJS)

bonus: $(OBJS) $(BOBJS)
	$(AR) $(NAME) $(OBJS) $(BOBJS)

$(OBJDIR)/%.o: %.s
	@mkdir -p $(OBJDIR)
	$(NASM) $(NFLAGS) $< -o $@

clean:
	rm -rf $(OBJDIR)

fclean: clean
	rm -f $(NAME)

re: fclean all

.PHONY: all bonus clean fclean re
