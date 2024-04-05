# Exercise 2

## Business Process Description

I am modeling a business process for class attendance and reservations at a yoga studio. The fact tables store data on class summaries and individual student attendance, while the dimension tables provide context about classes, students, and instructors. This model will help me analyze attendance, reservations, and class/instructor performance.

## Fact Table

## Fact Table: fact_class_summary
| Column Name | Type | Description |
| --- | --- | --- |
| class_id | integer | FK referencing dim_class table |
| class_date | datetime | Datetime of class |
| instructor_id | integer | Foreign key referencing the dim_instructor table |
| total_reservations | integer | Total number of reservations for the class |
| total_valid_checkins | integer | Total number of valid check-ins for the class |
| total_no_shows | integer | Total number of no-shows for the class |
| max_students | integer | Maximum number of students allowed in the class |

## Fact Table: fact_class_attendance
| Column Name | Type | Description |
| --- | --- | --- |
| fact_id | integer | PK identifying the attendance record |
| class_id | integer | FK referencing dim_class table |
| class_date | datetime | Datetime of the class |
| student_id | integer | FK referencing dim_student table |
| reservation_date | date | Date the reservation was made |
| no_show | boolean | Indicates if the student was a no-show for the class |

## Dimension

## Dimension Table: dim_class
| Column Name | Type | Description |
| --- | --- | --- |
| class_id | integer | PK identifying the class |
| class_name | varchar | Name of class |
| class_description | varchar | Description of class |
| class_duration | integer | Duration of class (m) |

## Dimension Table: dim_student
| Column Name | Type | Description |
| --- | --- | --- |
| student_id | integer | Primary key identifying the student |
| student_name | varchar | Name of student |
| student_email | varchar | Email address of student |
| student_phone | varchar | Phone number of student |
| student_join_date | date | Date student joined gym |

## Dimension Table: dim_instructor
| Column Name | Type | Description |
| --- | --- | --- |
| instructor_id | integer | PK identifying the instructor |
| instructor_name | varchar | Name of instructor |
| instructor_phone | varchar | Phone number of instructor |
| instructor_hire_date | date | Date instructor was hired |